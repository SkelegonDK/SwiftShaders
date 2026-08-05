#!/usr/bin/env python3
"""Extract the stitchable-function signatures out of a compiled metallib.

The metallib is the artifact the Swift side actually binds against, so it — not
the `.metal` sources — is the ground truth for what a call site must pass. Metal
exposes no runtime parameter reflection for `[[stitchable]]` functions
(`MTLFunction` has no parameter list, and a visible function cannot back a
compute pipeline), so the only way to recover the signatures is to disassemble.

    xcrun metal-objdump --metallib -d default.metallib

emits LLVM IR whose entry points look like:

    define <4 x half> @invert(<2 x float> noundef %0, <4 x half> noundef %1, float noundef %2) ...

Internal `define`s (the stitching-traits templates) are filtered out; only the
non-internal entry points are stitchable functions.

Output is a TSV manifest that gets checked in, so the Metal surface is
reviewable in diffs and available to tests that cannot shell out.

Usage: extract-metal-signatures.py [metallib] [output.tsv]
"""

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_METALLIB = REPO / "Sources/SwiftShaders/Resources/default.metallib"
DEFAULT_OUTPUT = REPO / "Sources/SwiftShaders/Resources/shader-signatures.tsv"
UNBOUND_OUTPUT = REPO / "Sources/SwiftShaders/Resources/unbound-functions.txt"
SWIFT_SOURCES = REPO / "Sources"

# `static let ripple = ShaderBinding.Distortion("ripple", geometry: .boundingRect …`
# — the one shape a binding is declared in. Kept in step with
# `Tests/…/Support/ShaderBindingSourceScanner.swift`, which parses the same line
# in Swift; the two are cross-checked by `UnboundFunctionInventoryTests`.
BINDING_DECLARATION = re.compile(
    r'ShaderBinding\.(?:Color|Distortion|Layer)\(\s*"(\w+)"'
)

DEFINE = re.compile(r"^define\s+(.+?)\s+@([A-Za-z_][A-Za-z0-9_]*)\((.*)\)\s+local_unnamed_addr")

# IR type -> MSL type. `metal::texture2d` and the `[5 x <2 x float>]` that
# follows it are the two halves of a single SwiftUI::Layer parameter; they are
# collapsed by `parse_parameters` rather than mapped here.
IR_TO_MSL = {
    "<2 x float>": "float2",
    "<3 x float>": "float3",
    "<4 x float>": "float4",
    "<2 x half>": "half2",
    "<3 x half>": "half3",
    "<4 x half>": "half4",
    "float": "float",
    "half": "half",
    "i32": "int",
    "i1": "bool",
}

# How many leading parameters SwiftUI supplies implicitly, per effect kind.
# Verified against the SwiftUICore doc comments (plan Phase 0.1): there is no
# implicit `bounds` and no implicit `size`.
IMPLICIT_PARAMETERS = {
    "colorEffect": 2,       # position, color
    "distortionEffect": 1,  # position
    "layerEffect": 2,       # position, layer
    "shapeStyle": 1,        # position
}


def split_top_level(text, openers="(<[{", closers=")>]}"):
    """Split on commas that are not nested inside brackets of any kind."""
    parts, depth, current = [], 0, ""
    for char in text:
        if char in openers:
            depth += 1
        elif char in closers:
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += char
    if current.strip():
        parts.append(current.strip())
    return [p for p in parts if p]


def parse_parameters(arglist):
    """IR parameter list -> ordered MSL type names, with Layer collapsed.

    A `SwiftUI::Layer` lowers to two IR parameters — the texture and a
    `[5 x <2 x float>]` transform block. Counting IR parameters naively
    over-counts every layerEffect by one, which is exactly the miscount this
    function exists to prevent.
    """
    types = []
    raw = split_top_level(arglist)
    index = 0
    while index < len(raw):
        # Strip parameter attributes (`noundef`) and the `%0` operand name.
        tokens = raw[index].split()
        ir_type = raw[index]
        for suffix in (" noundef", ):
            ir_type = ir_type.replace(suffix, "")
        ir_type = re.sub(r"\s*%\d+\s*$", "", ir_type).strip()

        if "texture2d" in ir_type:
            # Consume the transform block that always follows the texture.
            if index + 1 < len(raw) and "[5 x" in raw[index + 1]:
                index += 1
            types.append("layer")
        else:
            types.append(IR_TO_MSL.get(ir_type, ir_type))
        index += 1
        del tokens
    return types


def classify(return_type, parameters):
    """Effect kind from the IR shape alone.

    half4 + (float2, half4, ...) -> colorEffect
    half4 + (float2, layer, ...) -> layerEffect
    float2 + (float2, ...)       -> distortionEffect
    half4 + (float2, ...)        -> shapeStyle fill
    """
    if not parameters or parameters[0] != "float2":
        return "unknown"
    if return_type == "float2":
        return "distortionEffect"
    if return_type == "half4":
        if len(parameters) > 1 and parameters[1] == "half4":
            return "colorEffect"
        if len(parameters) > 1 and parameters[1] == "layer":
            return "layerEffect"
        return "shapeStyle"
    return "unknown"


def extract(metallib):
    disassembly = subprocess.run(
        ["xcrun", "metal-objdump", "--metallib", "-d", str(metallib)],
        capture_output=True, text=True, check=True,
    ).stdout

    rows = []
    for line in disassembly.splitlines():
        if not line.startswith("define") or " internal " in line:
            continue
        match = DEFINE.match(line)
        if not match:
            print(f"warning: unparsed entry point: {line[:120]}", file=sys.stderr)
            continue
        ir_return, name, arglist = match.groups()
        return_type = IR_TO_MSL.get(ir_return.strip(), ir_return.strip())
        parameters = parse_parameters(arglist)
        kind = classify(return_type, parameters)
        implicit = IMPLICIT_PARAMETERS.get(kind, 1)
        rows.append({
            "name": name,
            "kind": kind,
            "return_type": return_type,
            "explicit_argument_count": len(parameters) - implicit,
            "parameters": parameters,
        })
    return rows


def bound_function_names(sources=SWIFT_SOURCES):
    """Every Metal function some `ShaderBinding` declaration names."""
    names = set()
    for path in sorted(sources.rglob("*.swift")):
        names.update(BINDING_DECLARATION.findall(path.read_text()))
    return names


def write_unbound_inventory(rows, output=UNBOUND_OUTPUT):
    """List the stitchable functions no Swift binding reaches.

    These are shaders that compile, ship inside `default.metallib`, and cannot be
    invoked: nothing in the package names them. They are not defects — several
    are variants a future gallery entry would want — but they are invisible
    unless something writes them down, and an inventory nobody generates goes
    stale. Generated here so it cannot.
    """
    bound = bound_function_names()
    unbound = sorted(row["name"] for row in rows if row["name"] not in bound)

    header = [
        "# Stitchable Metal functions with no ShaderBinding declaration.",
        "#",
        "# GENERATED by Scripts/extract-metal-signatures.py — do not edit.",
        "# Regenerate with `bash Scripts/build-shaders.sh`.",
        "#",
        "# Each line is a function that exists in default.metallib and that no Swift",
        "# call site can reach. Binding one is the cheapest new effect in the",
        "# package: the shader is already written and already compiled.",
        "#",
        f"# {len(unbound)} unbound of {len(rows)} stitchable functions.",
        "",
    ]
    output.write_text("\n".join(header + unbound) + "\n")
    print(f"{len(unbound)} unbound functions -> {output.relative_to(REPO)}")
    return unbound


def main():
    metallib = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_METALLIB
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT

    if not metallib.exists():
        sys.exit(f"error: {metallib} not found. Run ./Scripts/build-shaders.sh first.")

    rows = extract(metallib)
    rows.sort(key=lambda r: r["name"])

    lines = ["name\tkind\treturn_type\texplicit_argument_count\tparameters"]
    for row in rows:
        lines.append("\t".join([
            row["name"], row["kind"], row["return_type"],
            str(row["explicit_argument_count"]), ",".join(row["parameters"]),
        ]))
    output.write_text("\n".join(lines) + "\n")

    histogram = {}
    for row in rows:
        histogram[row["kind"]] = histogram.get(row["kind"], 0) + 1
    print(f"{len(rows)} stitchable functions -> {output.relative_to(REPO)}")
    for kind in sorted(histogram):
        print(f"  {kind}: {histogram[kind]}")

    write_unbound_inventory(rows)

    duplicates = {r["name"] for r in rows if sum(1 for x in rows if x["name"] == r["name"]) > 1}
    if duplicates:
        sys.exit(f"error: duplicate function names in metallib: {sorted(duplicates)}")
    if any(r["kind"] == "unknown" for r in rows):
        unknown = [r["name"] for r in rows if r["kind"] == "unknown"]
        sys.exit(f"error: could not classify: {unknown}")


if __name__ == "__main__":
    main()
