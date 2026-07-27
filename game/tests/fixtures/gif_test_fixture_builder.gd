class_name GifTestFixtureBuilder
extends RefCounted

## Test-only plumbing: hand-builds a minimal valid GIF byte stream so
## GifDecoder has something real to decode against, since no ready-made
## test GIF exists in this project. Deliberately the simplest possible
## valid encoding -- Clear code, then one LITERAL code per pixel (no LZW
## back-reference compression at all), then End code -- since compression
## is optional per the GIF spec and getting the bit-packing right by hand
## is far easier to verify for a plain literal stream than for one that
## exercises dictionary growth.
##
## Fixed at a 4-color palette / min_code_size=2 (GIF's own minimum) --
## plenty for tiny test images.

const MIN_CODE_SIZE := 2
const CLEAR_CODE := 1 << MIN_CODE_SIZE
const END_CODE := CLEAR_CODE + 1

## frames: Array of {"pixels": PackedByteArray (width*height color indices,
## each 0-3), "delay_hundredths": int}. Every frame shares the same
## width/height/palette and fully overwrites the canvas (Image Descriptor
## always at 0,0 spanning the whole size) -- enough to prove multi-frame
## decoding without needing partial-rect/disposal-method test coverage too.
static func build(width: int, height: int, palette: PackedColorArray, frames: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.append_array("GIF89a".to_ascii_buffer())
	_append_u16(bytes, width)
	_append_u16(bytes, height)
	bytes.append(0x81)  # GCT present, size field = 1 -> 2^(1+1) = 4 entries
	bytes.append(0)  # background color index
	bytes.append(0)  # pixel aspect ratio

	for color in palette:
		bytes.append(int(round(color.r * 255.0)))
		bytes.append(int(round(color.g * 255.0)))
		bytes.append(int(round(color.b * 255.0)))

	for frame in frames:
		var pixels: PackedByteArray = frame["pixels"]
		var delay_hundredths: int = frame.get("delay_hundredths", 10)

		# Graphic Control Extension: delay only, no transparency, disposal 0.
		bytes.append(0x21)
		bytes.append(0xF9)
		bytes.append(4)
		bytes.append(0x00)
		_append_u16(bytes, delay_hundredths)
		bytes.append(0)  # transparent color index (unused, no transparency flag set)
		bytes.append(0)  # block terminator

		# Image Descriptor, always the full canvas at (0,0), no local color table.
		bytes.append(0x2C)
		_append_u16(bytes, 0)
		_append_u16(bytes, 0)
		_append_u16(bytes, width)
		_append_u16(bytes, height)
		bytes.append(0x00)
		bytes.append(MIN_CODE_SIZE)

		var lzw_bytes := _encode_literal_stream(pixels)
		# Single sub-block only -- correct as long as lzw_bytes stays under
		# 256 bytes, true for every tiny fixture this builder is meant for;
		# a real encoder would split larger streams across several
		# 255-byte-max sub-blocks.
		assert(lzw_bytes.size() < 256, "GifTestFixtureBuilder: fixture too large for single-sub-block encoding")
		bytes.append(lzw_bytes.size())
		bytes.append_array(lzw_bytes)
		bytes.append(0)  # sub-block terminator

	bytes.append(0x3B)  # Trailer
	return bytes

## Even a "no back-references, literal codes only" stream still has to
## widen its code width in lockstep with a compliant decoder's dictionary
## growth -- a decoder grows its table by one entry after every code
## (except the one immediately following Clear) *regardless* of whether
## the stream ever actually references those new entries, and switches to
## a wider code the instant that table size crosses a power of two. Get
## this wrong and the decoder silently starts reading the wrong bit width
## partway through the stream. (First found this the hard way: a 4-pixel
## test image decoded its first 3 pixels correctly and garbled the 4th --
## exactly where naive fixed-width encoding and real decoder-side growth
## first disagree.)
static func _encode_literal_stream(pixels: PackedByteArray) -> PackedByteArray:
	var code_size := MIN_CODE_SIZE + 1
	var next_code := END_CODE + 1
	var bit_buffer := 0
	var bit_count := 0
	var emitted := PackedByteArray()

	var codes_to_emit: Array[int] = [CLEAR_CODE]
	for idx in pixels:
		codes_to_emit.append(idx)
	codes_to_emit.append(END_CODE)

	var prev_had_entry := false
	for code in codes_to_emit:
		bit_buffer |= code << bit_count
		bit_count += code_size
		while bit_count >= 8:
			emitted.append(bit_buffer & 0xFF)
			bit_buffer >>= 8
			bit_count -= 8

		var is_clear_or_end := code == CLEAR_CODE or code == END_CODE
		if not is_clear_or_end:
			if prev_had_entry and next_code < 4096:
				next_code += 1
				if next_code >= (1 << code_size) and code_size < 12:
					code_size += 1
			prev_had_entry = true

	if bit_count > 0:
		emitted.append(bit_buffer & 0xFF)
	return emitted

static func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
