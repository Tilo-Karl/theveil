#!/usr/bin/env python3
"""Bake cleaned Ecto source-painting detail into the GLB UV layout."""

from __future__ import annotations

import json
import math
import struct
import zlib
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AR_DIR = ROOT / "ios" / "TheVeil" / "TheVeil" / "AR"
ASSET_DIR = ROOT / "ios" / "TheVeil" / "TheVeil" / "Assets.xcassets"
VIS_DIR = Path(
    "/Users/tilodelau/.codex/visualizations/2026/07/18/"
    "019f7531-b797-7c02-bca9-2a0f39c749a3"
)

SOURCE_VIEWS = {
    "front": ASSET_DIR / "EctoMeshFront.imageset" / "EctoMeshFront.png",
    "right": ASSET_DIR / "EctoMeshRight.imageset" / "EctoMeshRight.png",
    "back": ASSET_DIR / "EctoMeshBack.imageset" / "EctoMeshBack.png",
    "left": ASSET_DIR / "EctoLeft.imageset" / "EctoLeft.png",
}
GLB_PATH = ASSET_DIR / "Ecto2Lobes.dataset" / "Ecto2Lobes.glb"
FALLBACK_TEXTURE = AR_DIR / "Ecto2Lobes_BaseColor.png"
OUT_COLOR = AR_DIR / "EctoBodyOnlyColor.png"
OUT_MASK = AR_DIR / "EctoBodyOnlyMask.png"
OUT_PREVIEW = VIS_DIR / "ecto-body-only-uv-proof.png"

BAKE_SIZE = 2048
PREVIEW_SIZE = 860

MODEL_MIN = (-0.5002480149269104, -0.4640883207321167, -0.3622778654098511)
MODEL_MAX = (0.500241219997406, 0.4496261179447174, 0.3604147434234619)


def read_png_rgba(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")

    pos = 8
    width = height = color_type = bit_depth = None
    compressed = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
                raise ValueError(f"Unsupported PNG format for {path}")
        elif chunk_type == b"IDAT":
            compressed.extend(payload)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None or color_type is None:
        raise ValueError(f"Malformed PNG {path}")

    channels = 4 if color_type == 6 else 3
    bpp = channels
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    decoded_rows: list[bytearray] = []
    src = 0
    prev = bytearray(stride)
    for _ in range(height):
        filter_type = raw[src]
        src += 1
        row = bytearray(raw[src : src + stride])
        src += stride
        for i in range(stride):
            left = row[i - bpp] if i >= bpp else 0
            up = prev[i]
            up_left = prev[i - bpp] if i >= bpp else 0
            if filter_type == 1:
                row[i] = (row[i] + left) & 255
            elif filter_type == 2:
                row[i] = (row[i] + up) & 255
            elif filter_type == 3:
                row[i] = (row[i] + ((left + up) >> 1)) & 255
            elif filter_type == 4:
                row[i] = (row[i] + paeth(left, up, up_left)) & 255
            elif filter_type != 0:
                raise ValueError(f"Unsupported PNG filter {filter_type} in {path}")
        decoded_rows.append(row)
        prev = row

    rgba = bytearray(width * height * 4)
    dst = 0
    for row in decoded_rows:
        if channels == 4:
            rgba[dst : dst + width * 4] = row
            dst += width * 4
        else:
            for x in range(width):
                src_i = x * 3
                rgba[dst : dst + 4] = row[src_i : src_i + 3] + b"\xff"
                dst += 4
    return width, height, rgba


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def write_png_rgba(path: Path, width: int, height: int, rgba: bytearray | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(rgba[y * stride : (y + 1) * stride])
    payload = zlib.compress(bytes(rows), 6)
    chunks = [
        png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
        png_chunk(b"IDAT", payload),
        png_chunk(b"IEND", b""),
    ]
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"".join(chunks))


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def pixel_offset(width: int, x: int, y: int) -> int:
    return (y * width + x) * 4


def value_sat(r: int, g: int, b: int) -> tuple[int, int]:
    return max(r, g, b), max(r, g, b) - min(r, g, b)


def flood_background(width: int, height: int, rgba: bytearray) -> bytearray:
    def is_background(x: int, y: int) -> bool:
        i = pixel_offset(width, x, y)
        r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
        v, sat = value_sat(r, g, b)
        total = r + g + b
        return (total > 475 and sat < 105) or (v > 220 and sat < 80)

    background = bytearray(width * height)
    queue: deque[int] = deque()

    def push_if_bg(x: int, y: int) -> None:
        idx = y * width + x
        if background[idx] == 0 and is_background(x, y):
            background[idx] = 1
            queue.append(idx)

    for x in range(width):
        push_if_bg(x, 0)
        push_if_bg(x, height - 1)
    for y in range(height):
        push_if_bg(0, y)
        push_if_bg(width - 1, y)

    while queue:
        idx = queue.popleft()
        x = idx % width
        y = idx // width
        if x > 0:
            push_if_bg(x - 1, y)
        if x + 1 < width:
            push_if_bg(x + 1, y)
        if y > 0:
            push_if_bg(x, y - 1)
        if y + 1 < height:
            push_if_bg(x, y + 1)
    return background


def mask_bbox(width: int, height: int, mask: bytearray) -> tuple[int, int, int, int]:
    min_x, min_y = width, height
    max_x = max_y = -1
    for y in range(height):
        row = y * width
        for x in range(width):
            if mask[row + x]:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x:
        return 0, 0, width - 1, height - 1
    return min_x, min_y, max_x, max_y


def distance_from_background(width: int, height: int, silhouette: bytearray, max_dist: int) -> bytearray:
    distance = bytearray(width * height)
    frontier: deque[int] = deque()

    for y in range(height):
        row = y * width
        for x in range(width):
            idx = row + x
            if not silhouette[idx]:
                continue
            edge = (
                x == 0
                or y == 0
                or x + 1 == width
                or y + 1 == height
                or not silhouette[idx - 1]
                or not silhouette[idx + 1]
                or not silhouette[idx - width]
                or not silhouette[idx + width]
            )
            if edge:
                distance[idx] = 1
                frontier.append(idx)

    while frontier:
        idx = frontier.popleft()
        d = distance[idx]
        if d >= max_dist:
            continue
        x = idx % width
        for nidx in neighbor_indices(idx, x, width, height):
            if silhouette[nidx] and distance[nidx] == 0:
                distance[nidx] = d + 1
                frontier.append(nidx)
    return distance


def neighbor_indices(idx: int, x: int, width: int, height: int):
    if x > 0:
        yield idx - 1
    if x + 1 < width:
        yield idx + 1
    if idx >= width:
        yield idx - width
    if idx < width * (height - 1):
        yield idx + width


def dilate_mask(width: int, height: int, mask: bytearray, radius: int) -> bytearray:
    if radius <= 0:
        return bytearray(mask)
    result = bytearray(mask)
    frontier = deque((i, 0) for i, value in enumerate(mask) if value)
    seen = bytearray(mask)
    while frontier:
        idx, dist = frontier.popleft()
        if dist >= radius:
            continue
        x = idx % width
        for nidx in neighbor_indices(idx, x, width, height):
            if not seen[nidx]:
                seen[nidx] = 1
                result[nidx] = 1
                frontier.append((nidx, dist + 1))
    return result


def connected_large_warm_glow(width: int, height: int, rgba: bytearray, silhouette: bytearray) -> bytearray:
    seeds = bytearray(width * height)
    for y in range(height):
        yn = y / max(height - 1, 1)
        for x in range(width):
            idx = y * width + x
            if not silhouette[idx] or yn < 0.40:
                continue
            i = idx * 4
            r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
            warm = g > 178 and r > 130 and b < 132 and g > b + 58
            hot = g > 218 and r > 165 and b < 168
            if warm and hot:
                seeds[idx] = 1

    visited = bytearray(width * height)
    remove = bytearray(width * height)
    for idx, seed in enumerate(seeds):
        if not seed or visited[idx]:
            continue
        queue = deque([idx])
        visited[idx] = 1
        component: list[int] = []
        min_y = height
        max_y = 0
        while queue:
            current = queue.popleft()
            component.append(current)
            y = current // width
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            x = current % width
            for nidx in neighbor_indices(current, x, width, height):
                if seeds[nidx] and not visited[nidx]:
                    visited[nidx] = 1
                    queue.append(nidx)
        if len(component) > 850 and max_y > height * 0.52:
            for current in component:
                remove[current] = 1
    return dilate_mask(width, height, remove, 28)


def clean_source_view(name: str, path: Path) -> dict:
    width, height, rgba = read_png_rgba(path)
    background = flood_background(width, height, rgba)
    silhouette = bytearray(1 if not background[i] else 0 for i in range(width * height))
    bbox = mask_bbox(width, height, silhouette)
    edge_distance = distance_from_background(width, height, silhouette, 42)

    invalid = bytearray(width * height)
    specular_mask = bytearray(width * height)
    rim_mask = bytearray(width * height)
    face_seeds = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            i = idx * 4
            if not silhouette[idx]:
                invalid[idx] = 1
                continue
            r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
            v, sat = value_sat(r, g, b)
            dist = edge_distance[idx]
            dark_face = v < 54 and sat < 78
            black_feature = v < 74 and (g < 76 or r < 76) and b < 92
            white_specular = (v > 205 and sat < 54) or (v > 232 and min(r, g, b) > 138)
            rim_light = dist > 0 and dist < 15 and v > 135
            if dark_face or black_feature:
                face_seeds[idx] = 1
            if white_specular:
                specular_mask[idx] = 1
            if rim_light:
                rim_mask[idx] = 1
            if v < 58 and r < 58 and g < 72 and b < 88:
                face_seeds[idx] = 1
            if beauty_feature_region(name, x, y, bbox):
                face_seeds[idx] = 1
    face_mask = dilate_mask(width, height, face_seeds, 28)
    specular_mask = dilate_mask(width, height, specular_mask, 5)
    rim_mask = dilate_mask(width, height, rim_mask, 2)
    warm_glow = connected_large_warm_glow(width, height, rgba, silhouette)
    for idx in range(width * height):
        if face_mask[idx] or warm_glow[idx] or specular_mask[idx] or rim_mask[idx]:
            invalid[idx] = 1
        if not silhouette[idx]:
            invalid[idx] = 1

    valid = bytearray(1 if silhouette[i] and not invalid[i] else 0 for i in range(width * height))
    clean = bytearray(rgba)
    inpaint_broad_body_color(width, height, clean, silhouette, valid)
    tone_body_view(width, height, clean, silhouette)

    for idx in range(width * height):
        a = 255 if silhouette[idx] else 0
        clean[idx * 4 + 3] = a
        if not a:
            clean[idx * 4 : idx * 4 + 4] = b"\x00\x00\x00\x00"

    print(f"cleaned {name}: {width}x{height}, bbox={bbox}")
    return {
        "name": name,
        "width": width,
        "height": height,
        "rgba": clean,
        "mask": silhouette,
        "valid": valid,
        "bbox": bbox,
    }


def beauty_feature_region(name: str, x: int, y: int, bbox: tuple[int, int, int, int]) -> bool:
    min_x, min_y, max_x, max_y = bbox
    u = (x - min_x) / max(max_x - min_x, 1)
    v = (y - min_y) / max(max_y - min_y, 1)

    if name == "front":
        ellipses = [
            (0.365, 0.520, 0.178, 0.152),
            (0.635, 0.520, 0.178, 0.152),
            (0.500, 0.620, 0.165, 0.096),
        ]
    elif name == "right":
        ellipses = [
            (0.300, 0.502, 0.158, 0.134),
            (0.595, 0.486, 0.148, 0.128),
            (0.430, 0.594, 0.160, 0.096),
        ]
    elif name == "left":
        ellipses = [
            (0.405, 0.502, 0.148, 0.128),
            (0.700, 0.486, 0.158, 0.134),
            (0.565, 0.594, 0.160, 0.096),
        ]
    else:
        ellipses = []

    for cx, cy, rx, ry in ellipses:
        if ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0:
            return True
    return False


def inpaint_broad_body_color(width: int, height: int, rgba: bytearray, silhouette: bytearray, valid: bytearray) -> None:
    global_color = average_valid_color(width, height, rgba, valid)
    integrals = build_valid_color_integrals(width, height, rgba, valid)
    stride, sum_r, sum_g, sum_b, sum_w = integrals
    repair_mask = bytearray(1 if silhouette[i] and not valid[i] else 0 for i in range(width * height))

    for y in range(height):
        for x in range(width):
            idx = y * width + x
            if not repair_mask[idx]:
                continue

            color = None
            for radius in (46, 104, 218):
                x0 = max(0, x - radius)
                y0 = max(0, y - radius)
                x1 = min(width, x + radius + 1)
                y1 = min(height, y + radius + 1)
                weight = rect_sum(sum_w, stride, x0, y0, x1, y1)
                if weight >= 14:
                    color = (
                        rect_sum(sum_r, stride, x0, y0, x1, y1) / weight,
                        rect_sum(sum_g, stride, x0, y0, x1, y1) / weight,
                        rect_sum(sum_b, stride, x0, y0, x1, y1) / weight,
                    )
                    break

            if color is None:
                color = global_color

            dst = idx * 4
            rgba[dst] = clamp_int(color[0])
            rgba[dst + 1] = clamp_int(color[1])
            rgba[dst + 2] = clamp_int(color[2])
            rgba[dst + 3] = 255

    smooth_masked_region(width, height, rgba, silhouette, repair_mask, passes=18)


def average_valid_color(width: int, height: int, rgba: bytearray, valid: bytearray) -> tuple[float, float, float]:
    totals = [0, 0, 0]
    count = 0
    for idx, is_valid in enumerate(valid):
        if not is_valid:
            continue
        i = idx * 4
        totals[0] += rgba[i]
        totals[1] += rgba[i + 1]
        totals[2] += rgba[i + 2]
        count += 1
    if count == 0:
        return (58.0, 170.0, 34.0)
    return (totals[0] / count, totals[1] / count, totals[2] / count)


def build_valid_color_integrals(
    width: int, height: int, rgba: bytearray, valid: bytearray
) -> tuple[int, list[int], list[int], list[int], list[int]]:
    stride = width + 1
    total = (height + 1) * stride
    sum_r = [0] * total
    sum_g = [0] * total
    sum_b = [0] * total
    sum_w = [0] * total

    for y in range(1, height + 1):
        row_r = row_g = row_b = row_w = 0
        src_row = (y - 1) * width
        current_row = y * stride
        previous_row = (y - 1) * stride
        for x in range(1, width + 1):
            idx = src_row + x - 1
            if valid[idx]:
                i = idx * 4
                row_r += rgba[i]
                row_g += rgba[i + 1]
                row_b += rgba[i + 2]
                row_w += 1
            dst = current_row + x
            above = previous_row + x
            sum_r[dst] = sum_r[above] + row_r
            sum_g[dst] = sum_g[above] + row_g
            sum_b[dst] = sum_b[above] + row_b
            sum_w[dst] = sum_w[above] + row_w

    return stride, sum_r, sum_g, sum_b, sum_w


def rect_sum(integral: list[int], stride: int, x0: int, y0: int, x1: int, y1: int) -> int:
    return (
        integral[y1 * stride + x1]
        - integral[y0 * stride + x1]
        - integral[y1 * stride + x0]
        + integral[y0 * stride + x0]
    )


def smooth_masked_region(
    width: int,
    height: int,
    rgba: bytearray,
    silhouette: bytearray,
    smooth_mask: bytearray,
    passes: int,
) -> None:
    for _ in range(passes):
        next_rgba = bytearray(rgba)
        for idx, needs_smooth in enumerate(smooth_mask):
            if not needs_smooth:
                continue
            x = idx % width
            src = idx * 4
            totals = [
                rgba[src] * 3,
                rgba[src + 1] * 3,
                rgba[src + 2] * 3,
            ]
            count = 3
            for nidx in neighbor_indices(idx, x, width, height):
                if not silhouette[nidx]:
                    continue
                ni = nidx * 4
                totals[0] += rgba[ni]
                totals[1] += rgba[ni + 1]
                totals[2] += rgba[ni + 2]
                count += 1
            next_rgba[src] = totals[0] // count
            next_rgba[src + 1] = totals[1] // count
            next_rgba[src + 2] = totals[2] // count
            next_rgba[src + 3] = 255
        rgba[:] = next_rgba


def tone_body_view(width: int, height: int, rgba: bytearray, silhouette: bytearray) -> None:
    for idx in range(width * height):
        if not silhouette[idx]:
            continue
        i = idx * 4
        r, g, b = rgba[i], rgba[i + 1], rgba[i + 2]
        v = max(r, g, b)
        if v > 212:
            scale = 212 / v
            r = int(r * scale)
            g = int(g * scale)
            b = int(b * scale)
        # Keep it as authored green/yellow/cyan detail, but make it albedo-like.
        rgba[i] = clamp_int(r * 0.88 + 2)
        rgba[i + 1] = clamp_int(g * 0.92 + 5)
        rgba[i + 2] = clamp_int(b * 0.90 + 2)


def clamp_int(value: float) -> int:
    return max(0, min(255, int(round(value))))


def parse_glb_mesh(path: Path) -> tuple[list[tuple[float, float, float]], list[tuple[float, float]], list[int]]:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError(f"{path} is not a GLB")
    pos = 12
    chunks: list[tuple[int, int, int]] = []
    while pos < len(data):
        length, chunk_type = struct.unpack_from("<II", data, pos)
        pos += 8
        chunks.append((chunk_type, pos, length))
        pos += length
    json_chunk = data[chunks[0][1] : chunks[0][1] + chunks[0][2]]
    bin_chunk = data[chunks[1][1] : chunks[1][1] + chunks[1][2]]
    gltf = json.loads(json_chunk.decode("utf-8"))
    primitive = gltf["meshes"][0]["primitives"][0]
    positions = read_accessor(gltf, bin_chunk, primitive["attributes"]["POSITION"])
    texcoords = read_accessor(gltf, bin_chunk, primitive["attributes"]["TEXCOORD_0"])
    indices = read_accessor(gltf, bin_chunk, primitive["indices"])
    return positions, texcoords, [int(i[0] if isinstance(i, tuple) else i) for i in indices]


def read_accessor(gltf: dict, bin_chunk: bytes, accessor_index: int):
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    count = accessor["count"]
    value_type = accessor["type"]
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[value_type]
    component_format = {5125: "I", 5126: "f", 5123: "H", 5121: "B"}[component_type]
    component_size = struct.calcsize("<" + component_format)
    stride = view.get("byteStride", component_size * components)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    values = []
    for i in range(count):
        base = offset + i * stride
        packed = struct.unpack_from("<" + component_format * components, bin_chunk, base)
        values.append(packed if components > 1 else packed[0])
    return values


def compute_vertex_normals(
    positions: list[tuple[float, float, float]], indices: list[int]
) -> list[tuple[float, float, float]]:
    normals = [[0.0, 0.0, 0.0] for _ in positions]
    for i in range(0, len(indices), 3):
        ia, ib, ic = indices[i], indices[i + 1], indices[i + 2]
        a, b, c = positions[ia], positions[ib], positions[ic]
        ab = sub3(b, a)
        ac = sub3(c, a)
        n = cross(ab, ac)
        for vi in (ia, ib, ic):
            normals[vi][0] += n[0]
            normals[vi][1] += n[1]
            normals[vi][2] += n[2]
    return [normalize3(tuple(n)) for n in normals]


def sub3(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def normalize3(v):
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length <= 1e-8:
        return (0.0, 0.0, 1.0)
    return (v[0] / length, v[1] / length, v[2] / length)


def dot3(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def mix3(a, b, t):
    return (
        a[0] * (1.0 - t) + b[0] * t,
        a[1] * (1.0 - t) + b[1] * t,
        a[2] * (1.0 - t) + b[2] * t,
    )


def body_x(position):
    return saturate((position[0] - MODEL_MIN[0]) / (MODEL_MAX[0] - MODEL_MIN[0]))


def body_y(position):
    return saturate(1.0 - ((position[1] - MODEL_MIN[1]) / (MODEL_MAX[1] - MODEL_MIN[1])))


def body_z(position):
    return saturate((position[2] - MODEL_MIN[2]) / (MODEL_MAX[2] - MODEL_MIN[2]))


def saturate(value):
    return max(0.0, min(1.0, value))


def smoothstep(edge0, edge1, x):
    t = saturate((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def sample_view(image: dict, u: float, v: float) -> tuple[tuple[float, float, float], float, float]:
    width = image["width"]
    height = image["height"]
    rgba = image["rgba"]
    bbox = image["bbox"]
    x = bbox[0] + saturate(u) * max(1, bbox[2] - bbox[0])
    y = bbox[1] + saturate(v) * max(1, bbox[3] - bbox[1])
    color = sample_raw_rgba(width, height, rgba, x / max(width - 1, 1), y / max(height - 1, 1))[:3]
    valid = sample_mask(width, height, image["valid"], x / max(width - 1, 1), y / max(height - 1, 1))
    raw = sample_mask(width, height, image["mask"], x / max(width - 1, 1), y / max(height - 1, 1))
    return color, valid, raw


def sample_mask(width: int, height: int, mask: bytearray, u: float, v: float) -> float:
    x = saturate(u) * (width - 1)
    y = saturate(v) * (height - 1)
    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = min(width - 1, x0 + 1)
    y1 = min(height - 1, y0 + 1)
    tx = x - x0
    ty = y - y0

    def m(px: int, py: int) -> float:
        return float(mask[py * width + px])

    top = m(x0, y0) * (1.0 - tx) + m(x1, y0) * tx
    bottom = m(x0, y1) * (1.0 - tx) + m(x1, y1) * tx
    return top * (1.0 - ty) + bottom * ty


def sample_raw_rgba(
    width: int, height: int, rgba: bytearray, u: float, v: float
) -> tuple[float, float, float, float]:
    x = saturate(u) * (width - 1)
    y = saturate(v) * (height - 1)
    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = min(width - 1, x0 + 1)
    y1 = min(height - 1, y0 + 1)
    tx = x - x0
    ty = y - y0

    def p(px: int, py: int):
        i = pixel_offset(width, px, py)
        return rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]

    c00 = p(x0, y0)
    c10 = p(x1, y0)
    c01 = p(x0, y1)
    c11 = p(x1, y1)
    out = []
    for channel in range(4):
        top = c00[channel] * (1.0 - tx) + c10[channel] * tx
        bottom = c01[channel] * (1.0 - tx) + c11[channel] * tx
        out.append((top * (1.0 - ty) + bottom * ty) / 255.0)
    return tuple(out)


def sample_body_source(
    views: dict, fallback: tuple[int, int, bytearray], position, normal, uv
) -> tuple[tuple[float, float, float], float, bool]:
    x = body_x(position)
    y = body_y(position)
    z = body_z(position)
    samples = {
        "front": sample_view(views["front"], x, y),
        "right": sample_view(views["right"], 1.0 - z, y),
        "back": sample_view(views["back"], 1.0 - x, y),
        "left": sample_view(views["left"], z, y),
    }

    n = normalize3(normal)
    weights = {
        "front": max(saturate(n[2]) ** 1.45, smoothstep(-0.24, 0.18, position[2]) * 0.34),
        "right": max(saturate(n[0]) ** 1.35, smoothstep(0.16, 0.43, position[0]) * 0.62),
        "back": max(saturate(-n[2]) ** 1.45, smoothstep(-0.24, 0.18, -position[2]) * 0.30),
        "left": max(saturate(-n[0]) ** 1.35, smoothstep(0.16, 0.43, -position[0]) * 0.62),
    }

    weighted = [0.0, 0.0, 0.0]
    raw_weighted = [0.0, 0.0, 0.0]
    total = 0.0
    raw_total = 0.0
    for name, sample in samples.items():
        source_color, valid_alpha, raw_alpha = sample
        coverage = smoothstep(0.18, 0.82, valid_alpha)
        raw_coverage = smoothstep(0.18, 0.82, raw_alpha)
        weight = weights[name] * coverage
        raw_weight = weights[name] * raw_coverage
        raw_total += raw_weight
        total += weight
        weighted[0] += source_color[0] * weight
        weighted[1] += source_color[1] * weight
        weighted[2] += source_color[2] * weight
        raw_weighted[0] += source_color[0] * raw_weight
        raw_weighted[1] += source_color[1] * raw_weight
        raw_weighted[2] += source_color[2] * raw_weight

    if total > 0.0001:
        source = (weighted[0] / total, weighted[1] / total, weighted[2] / total)
        coverage = saturate(total)
        return source, coverage, True

    if raw_total > 0.03:
        source = (
            raw_weighted[0] / raw_total,
            raw_weighted[1] / raw_total,
            raw_weighted[2] / raw_total,
        )
        return source, saturate(raw_total * 0.34), True

    fw, fh, frgba = fallback
    fallback_color = sample_raw_rgba(fw, fh, frgba, uv[0], uv[1])[:3]
    return tone_fallback(fallback_color), 0.35, False


def tone_fallback(color):
    r, g, b = color
    v = max(color)
    if v > 0.72:
        scale = 0.72 / v
        r, g, b = r * scale, g * scale, b * scale
    return (r * 0.75 + 0.02, g * 0.82 + 0.035, b * 0.72 + 0.01)


def bake_uv_texture(
    positions, texcoords, normals, indices, views, fallback
) -> tuple[bytearray, bytearray]:
    size = BAKE_SIZE
    color = bytearray(size * size * 4)
    validity_mask = bytearray(size * size)
    mesh_mask = bytearray(size * size)
    quality = [0.0] * (size * size)

    for tri in range(0, len(indices), 3):
        ia, ib, ic = indices[tri], indices[tri + 1], indices[tri + 2]
        uv0, uv1, uv2 = texcoords[ia], texcoords[ib], texcoords[ic]
        p0 = (uv0[0] * (size - 1), uv0[1] * (size - 1))
        p1 = (uv1[0] * (size - 1), uv1[1] * (size - 1))
        p2 = (uv2[0] * (size - 1), uv2[1] * (size - 1))
        min_x = max(0, int(math.floor(min(p0[0], p1[0], p2[0]))) - 1)
        max_x = min(size - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))) + 1)
        min_y = max(0, int(math.floor(min(p0[1], p1[1], p2[1]))) - 1)
        max_y = min(size - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))) + 1)
        denom = (
            (p1[1] - p2[1]) * (p0[0] - p2[0])
            + (p2[0] - p1[0]) * (p0[1] - p2[1])
        )
        if abs(denom) < 1e-8:
            continue
        for y in range(min_y, max_y + 1):
            py = y + 0.5
            for x in range(min_x, max_x + 1):
                px = x + 0.5
                w0 = ((p1[1] - p2[1]) * (px - p2[0]) + (p2[0] - p1[0]) * (py - p2[1])) / denom
                w1 = ((p2[1] - p0[1]) * (px - p2[0]) + (p0[0] - p2[0]) * (py - p2[1])) / denom
                w2 = 1.0 - w0 - w1
                if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
                    continue
                position = interpolate3(positions[ia], positions[ib], positions[ic], w0, w1, w2)
                normal = normalize3(interpolate3(normals[ia], normals[ib], normals[ic], w0, w1, w2))
                uv = (
                    uv0[0] * w0 + uv1[0] * w1 + uv2[0] * w2,
                    uv0[1] * w0 + uv1[1] * w1 + uv2[1] * w2,
                )
                out_idx = y * size + x
                mesh_mask[out_idx] = 255
                sample, coverage, authored = sample_body_source(views, fallback, position, normal, uv)
                if coverage <= 0.0001:
                    continue
                if coverage + 0.001 < quality[out_idx]:
                    continue
                quality[out_idx] = coverage
                dst = out_idx * 4
                color[dst] = clamp_int(sample[0] * 255)
                color[dst + 1] = clamp_int(sample[1] * 255)
                color[dst + 2] = clamp_int(sample[2] * 255)
                color[dst + 3] = 255
                validity_mask[out_idx] = clamp_int(coverage * (255 if authored else 120))

    fill_uv_holes(size, color, mesh_mask, quality)
    smooth_low_quality_uv(size, color, mesh_mask, quality)
    for idx, covered in enumerate(mesh_mask):
        if covered:
            color[idx * 4 + 3] = 255
    fill_texture_padding(size, color, mesh_mask)
    mask_rgba = bytearray(size * size * 4)
    for idx, alpha in enumerate(validity_mask):
        dst = idx * 4
        mask_rgba[dst : dst + 4] = bytes((alpha, alpha, alpha, 255))
    return color, mask_rgba


def interpolate3(a, b, c, w0, w1, w2):
    return (
        a[0] * w0 + b[0] * w1 + c[0] * w2,
        a[1] * w0 + b[1] * w1 + c[1] * w2,
        a[2] * w0 + b[2] * w1 + c[2] * w2,
    )


def pad_uv_edges(size: int, color: bytearray, mask: bytearray, radius: int) -> None:
    assigned = bytearray(1 if value > 0 else 0 for value in mask)
    queue = deque((i, 0) for i, value in enumerate(assigned) if value)
    while queue:
        idx, dist = queue.popleft()
        if dist >= radius:
            continue
        x = idx % size
        src = idx * 4
        for nidx in neighbor_indices(idx, x, size, size):
            if not assigned[nidx]:
                assigned[nidx] = 1
                dst = nidx * 4
                color[dst : dst + 3] = color[src : src + 3]
                color[dst + 3] = 0
                queue.append((nidx, dist + 1))


def fill_texture_padding(size: int, color: bytearray, mesh_mask: bytearray) -> None:
    assigned = bytearray(1 if value > 0 else 0 for value in mesh_mask)
    queue: deque[int] = deque(i for i, value in enumerate(assigned) if value)

    if not queue:
        for idx in range(size * size):
            dst = idx * 4
            color[dst : dst + 4] = b"\x2e\x90\x19\xff"
        return

    while queue:
        idx = queue.popleft()
        x = idx % size
        src = idx * 4
        for nidx in neighbor_indices(idx, x, size, size):
            if assigned[nidx]:
                continue
            assigned[nidx] = 1
            dst = nidx * 4
            color[dst : dst + 3] = color[src : src + 3]
            color[dst + 3] = 255
            queue.append(nidx)

    for idx in range(size * size):
        color[idx * 4 + 3] = 255


def smooth_low_quality_uv(
    size: int,
    color: bytearray,
    mesh_mask: bytearray,
    quality: list[float],
    threshold: float = 0.48,
    passes: int = 12,
) -> None:
    smooth = bytearray(1 if mesh_mask[i] and quality[i] < threshold else 0 for i in range(size * size))
    for _ in range(passes):
        next_color = bytearray(color)
        for idx, needs_smooth in enumerate(smooth):
            if not needs_smooth:
                continue
            x = idx % size
            src = idx * 4
            totals = [
                color[src] * 2,
                color[src + 1] * 2,
                color[src + 2] * 2,
            ]
            count = 2
            for nidx in neighbor_indices(idx, x, size, size):
                if not mesh_mask[nidx]:
                    continue
                ni = nidx * 4
                totals[0] += color[ni]
                totals[1] += color[ni + 1]
                totals[2] += color[ni + 2]
                count += 1
            next_color[src] = totals[0] // count
            next_color[src + 1] = totals[1] // count
            next_color[src + 2] = totals[2] // count
            next_color[src + 3] = 255
        color[:] = next_color


def fill_uv_holes(size: int, color: bytearray, mesh_mask: bytearray, quality: list[float]) -> None:
    assigned = bytearray(1 if mesh_mask[i] and quality[i] > 0.0001 else 0 for i in range(size * size))
    queue: deque[int] = deque(i for i, value in enumerate(assigned) if value)
    while queue:
        idx = queue.popleft()
        x = idx % size
        src = idx * 4
        for nidx in neighbor_indices(idx, x, size, size):
            if mesh_mask[nidx] and not assigned[nidx]:
                assigned[nidx] = 1
                quality[nidx] = 0.04
                dst = nidx * 4
                color[dst : dst + 3] = color[src : src + 3]
                color[dst + 3] = 255
                queue.append(nidx)

    if any(mesh_mask[i] and not assigned[i] for i in range(size * size)):
        visited = bytearray(assigned)
        queue = deque(i for i, value in enumerate(assigned) if value)
        while queue:
            idx = queue.popleft()
            x = idx % size
            src = idx * 4
            for nidx in neighbor_indices(idx, x, size, size):
                if visited[nidx]:
                    continue
                visited[nidx] = 1
                dst = nidx * 4
                color[dst : dst + 3] = color[src : src + 3]
                if mesh_mask[nidx]:
                    color[dst + 3] = 255
                    assigned[nidx] = 1
                    quality[nidx] = 0.03
                queue.append(nidx)

    smooth = bytearray(1 if mesh_mask[i] and quality[i] <= 0.05 else 0 for i in range(size * size))
    for _ in range(4):
        next_color = bytearray(color)
        for idx, needs_smooth in enumerate(smooth):
            if not needs_smooth:
                continue
            x = idx % size
            totals = [0, 0, 0]
            count = 0
            for nidx in neighbor_indices(idx, x, size, size):
                if mesh_mask[nidx]:
                    ni = nidx * 4
                    totals[0] += color[ni]
                    totals[1] += color[ni + 1]
                    totals[2] += color[ni + 2]
                    count += 1
            if count:
                dst = idx * 4
                next_color[dst] = totals[0] // count
                next_color[dst + 1] = totals[1] // count
                next_color[dst + 2] = totals[2] // count
                next_color[dst + 3] = 255
        color[:] = next_color


def render_preview(positions, texcoords, indices, texture: bytearray) -> bytearray:
    sheet_w = PREVIEW_SIZE * 2
    sheet_h = PREVIEW_SIZE * 2
    sheet = bytearray([18, 24, 25, 255] * (sheet_w * sheet_h))
    views = [
        ("front", lambda p: (p[0], p[1], -p[2])),
        ("right", lambda p: (-p[2], p[1], -p[0])),
        ("back", lambda p: (-p[0], p[1], p[2])),
        ("left", lambda p: (p[2], p[1], p[0])),
    ]
    for view_index, (_, projector) in enumerate(views):
        tile_x = (view_index % 2) * PREVIEW_SIZE
        tile_y = (view_index // 2) * PREVIEW_SIZE
        render_view(tile_x, tile_y, sheet_w, sheet, positions, texcoords, indices, texture, projector)
    return sheet


def render_view(tile_x, tile_y, sheet_w, sheet, positions, texcoords, indices, texture, projector):
    projected = [projector(p) for p in positions]
    min_x = min(p[0] for p in projected)
    max_x = max(p[0] for p in projected)
    min_y = min(p[1] for p in projected)
    max_y = max(p[1] for p in projected)
    scale = PREVIEW_SIZE * 0.78 / max(max_x - min_x, max_y - min_y)
    cx = (min_x + max_x) * 0.5
    cy = (min_y + max_y) * 0.5
    screen = [
        (
            tile_x + PREVIEW_SIZE * 0.5 + (p[0] - cx) * scale,
            tile_y + PREVIEW_SIZE * 0.5 - (p[1] - cy) * scale,
            p[2],
        )
        for p in projected
    ]
    zbuf = [1e9] * (PREVIEW_SIZE * PREVIEW_SIZE)
    for tri in range(0, len(indices), 3):
        ia, ib, ic = indices[tri], indices[tri + 1], indices[tri + 2]
        p0, p1, p2 = screen[ia], screen[ib], screen[ic]
        min_px = max(tile_x, int(math.floor(min(p0[0], p1[0], p2[0]))))
        max_px = min(tile_x + PREVIEW_SIZE - 1, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        min_py = max(tile_y, int(math.floor(min(p0[1], p1[1], p2[1]))))
        max_py = min(tile_y + PREVIEW_SIZE - 1, int(math.ceil(max(p0[1], p1[1], p2[1]))))
        denom = (
            (p1[1] - p2[1]) * (p0[0] - p2[0])
            + (p2[0] - p1[0]) * (p0[1] - p2[1])
        )
        if abs(denom) < 1e-8:
            continue
        for y in range(min_py, max_py + 1):
            for x in range(min_px, max_px + 1):
                px = x + 0.5
                py = y + 0.5
                w0 = ((p1[1] - p2[1]) * (px - p2[0]) + (p2[0] - p1[0]) * (py - p2[1])) / denom
                w1 = ((p2[1] - p0[1]) * (px - p2[0]) + (p0[0] - p2[0]) * (py - p2[1])) / denom
                w2 = 1.0 - w0 - w1
                if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
                    continue
                depth = p0[2] * w0 + p1[2] * w1 + p2[2] * w2
                local = (y - tile_y) * PREVIEW_SIZE + (x - tile_x)
                if depth >= zbuf[local]:
                    continue
                zbuf[local] = depth
                uv0, uv1, uv2 = texcoords[ia], texcoords[ib], texcoords[ic]
                u = uv0[0] * w0 + uv1[0] * w1 + uv2[0] * w2
                v = uv0[1] * w0 + uv1[1] * w1 + uv2[1] * w2
                r, g, b, _ = sample_raw_rgba(BAKE_SIZE, BAKE_SIZE, texture, u, v)
                dst = (y * sheet_w + x) * 4
                sheet[dst] = clamp_int(r * 255)
                sheet[dst + 1] = clamp_int(g * 255)
                sheet[dst + 2] = clamp_int(b * 255)
                sheet[dst + 3] = 255


def main() -> None:
    views = {name: clean_source_view(name, path) for name, path in SOURCE_VIEWS.items()}
    fallback = read_png_rgba(FALLBACK_TEXTURE)
    positions, texcoords, indices = parse_glb_mesh(GLB_PATH)
    normals = compute_vertex_normals(positions, indices)
    print(f"parsed mesh: vertices={len(positions)}, triangles={len(indices) // 3}")
    color, mask = bake_uv_texture(positions, texcoords, normals, indices, views, fallback)
    write_png_rgba(OUT_COLOR, BAKE_SIZE, BAKE_SIZE, color)
    write_png_rgba(OUT_MASK, BAKE_SIZE, BAKE_SIZE, mask)
    preview = render_preview(positions, texcoords, indices, color)
    write_png_rgba(OUT_PREVIEW, PREVIEW_SIZE * 2, PREVIEW_SIZE * 2, preview)
    print(f"wrote {OUT_COLOR}")
    print(f"wrote {OUT_MASK}")
    print(f"wrote {OUT_PREVIEW}")


if __name__ == "__main__":
    main()
