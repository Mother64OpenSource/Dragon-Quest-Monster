class_name GifDecoder
extends RefCounted

## Minimal GIF87a/89a decoder. Godot has no built-in animated-GIF playback
## (Image.load() only ever gives you the first frame) -- this exists so
## uploading a .gif as a background actually plays, rather than silently
## degrading to a static frame.
##
## Covers what real-world GIF exporters actually produce: global and/or
## per-frame local color tables, LZW-compressed frame data, and the
## Graphic Control Extension for per-frame delay/transparency/disposal.
## Application, Comment, and Plain Text extensions are skipped entirely
## (Plain Text in particular is essentially never used by modern encoders).
##
## Two deliberate simplifications, not full spec compliance:
## - Interlaced frames are read in file row order, not deinterlaced --
##   rare in modern exports, and correct deinterlacing is a real second
##   chunk of complexity for a case this is unlikely to ever hit.
## - Disposal method 3 ("restore to previous") is treated the same as
##   0/1 ("leave as-is") rather than a full canvas undo-stack -- also rare
##   in practice, and the visual difference even when it appears is minor.

const DISPOSAL_RESTORE_BACKGROUND := 2

## Returns Array[GifFrame], or an empty array (with a pushed error) if
## `bytes` isn't a readable GIF at all.
static func decode(bytes: PackedByteArray) -> Array:
	var frames: Array = []
	if bytes.size() < 13 or not _has_gif_header(bytes):
		push_error("GifDecoder: not a GIF file (bad or missing header)")
		return frames

	var pos := 6
	var canvas_width := bytes.decode_u16(pos)
	var canvas_height := bytes.decode_u16(pos + 2)
	var screen_packed := bytes[pos + 4]
	pos += 7  # width(2) + height(2) + packed(1) + bg color index(1) + pixel aspect(1)

	var global_color_table := PackedColorArray()
	if screen_packed & 0x80 != 0:
		var gct_size := 2 << (screen_packed & 0x07)
		global_color_table = _read_color_table(bytes, pos, gct_size)
		pos += gct_size * 3

	if canvas_width <= 0 or canvas_height <= 0:
		push_error("GifDecoder: invalid canvas size %dx%d" % [canvas_width, canvas_height])
		return frames

	var canvas := Image.create(canvas_width, canvas_height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var pending_delay_sec := 0.1
	var pending_transparent_index := -1
	var pending_disposal := 0

	while pos < bytes.size():
		var introducer := bytes[pos]
		if introducer == 0x3B:  # Trailer
			break
		elif introducer == 0x21:  # Extension Introducer
			pos += 1
			if pos >= bytes.size():
				break
			var label := bytes[pos]
			pos += 1
			if label == 0xF9:  # Graphic Control Extension
				var block_size := bytes[pos]
				var gce_packed := bytes[pos + 1]
				pending_disposal = (gce_packed >> 2) & 0x07
				var has_transparency := (gce_packed & 0x01) != 0
				var delay_hundredths := bytes.decode_u16(pos + 2)
				# 0-delay frames are common but unwatchable at native speed --
				# a small floor keeps playback from looking frozen/broken.
				pending_delay_sec = (delay_hundredths / 100.0) if delay_hundredths > 0 else 0.1
				pending_transparent_index = bytes[pos + 4] if has_transparency else -1
				pos += 1 + block_size
				pos = _skip_terminator(bytes, pos)
			else:
				pos = _skip_sub_blocks(bytes, pos)
		elif introducer == 0x2C:  # Image Descriptor
			pos += 1
			var img_left := bytes.decode_u16(pos)
			var img_top := bytes.decode_u16(pos + 2)
			var img_width := bytes.decode_u16(pos + 4)
			var img_height := bytes.decode_u16(pos + 6)
			var img_packed := bytes[pos + 8]
			pos += 9

			var color_table := global_color_table
			if img_packed & 0x80 != 0:
				var lct_size := 2 << (img_packed & 0x07)
				color_table = _read_color_table(bytes, pos, lct_size)
				pos += lct_size * 3

			if pos >= bytes.size():
				break
			var min_code_size := bytes[pos]
			pos += 1
			var sub_blocks := _read_sub_blocks(bytes, pos)
			pos = sub_blocks["next_pos"]
			var indices: PackedByteArray = _lzw_decode(sub_blocks["data"], min_code_size, img_width * img_height)

			_blit_frame(canvas, indices, img_left, img_top, img_width, img_height, color_table, pending_transparent_index)
			var frame_image := canvas.duplicate()
			frames.append(GifFrame.new(ImageTexture.create_from_image(frame_image), pending_delay_sec))

			if pending_disposal == DISPOSAL_RESTORE_BACKGROUND:
				_clear_rect(canvas, img_left, img_top, img_width, img_height)

			pending_transparent_index = -1
			pending_disposal = 0
		else:
			# Unknown/malformed block -- bail out gracefully with whatever
			# frames decoded successfully so far, rather than looping forever.
			break

	return frames

static func _has_gif_header(bytes: PackedByteArray) -> bool:
	var header := bytes.slice(0, 6).get_string_from_ascii()
	return header == "GIF87a" or header == "GIF89a"

static func _read_color_table(bytes: PackedByteArray, pos: int, count: int) -> PackedColorArray:
	var table := PackedColorArray()
	table.resize(count)
	for i in range(count):
		var base := pos + i * 3
		if base + 2 >= bytes.size():
			table[i] = Color.BLACK
			continue
		table[i] = Color(bytes[base] / 255.0, bytes[base + 1] / 255.0, bytes[base + 2] / 255.0, 1.0)
	return table

## Extension sub-blocks we don't care about (Application/Comment/Plain
## Text) -- just advance past them.
static func _skip_sub_blocks(bytes: PackedByteArray, start_pos: int) -> int:
	var pos := start_pos
	while pos < bytes.size():
		var block_size := bytes[pos]
		pos += 1
		if block_size == 0:
			break
		pos += block_size
	return pos

## Same sub-block walk, but concatenating the actual bytes -- used for
## image data, which IS sub-block-encoded (unlike the GCE's fixed-size block).
static func _read_sub_blocks(bytes: PackedByteArray, start_pos: int) -> Dictionary:
	var data := PackedByteArray()
	var pos := start_pos
	while pos < bytes.size():
		var block_size := bytes[pos]
		pos += 1
		if block_size == 0:
			break
		data.append_array(bytes.slice(pos, pos + block_size))
		pos += block_size
	return {"data": data, "next_pos": pos}

static func _skip_terminator(bytes: PackedByteArray, pos: int) -> int:
	if pos < bytes.size() and bytes[pos] == 0:
		return pos + 1
	return pos

## Fresh LZW dictionary: codes 0..clear_code-1 are literal single-byte
## sequences, clear_code/end_code get placeholder (never-read) slots so
## every OTHER code's index lines up directly with its array position.
static func _fresh_lzw_dictionary(clear_code: int) -> Array:
	var dictionary: Array = []
	for i in range(clear_code):
		var single := PackedByteArray()
		single.append(i)
		dictionary.append(single)
	dictionary.append(PackedByteArray())  # clear_code slot
	dictionary.append(PackedByteArray())  # end_code slot
	return dictionary

## Standard GIF-variant LZW decode: variable-width codes (min_code_size+1
## bits, growing up to 12), packed LSB-first across byte boundaries.
## Pre-sized to expected_pixel_count and only ever writes up to that many
## bytes, so a truncated/corrupt stream degrades to a partial frame instead
## of a crash or an infinite loop.
static func _lzw_decode(data: PackedByteArray, min_code_size: int, expected_pixel_count: int) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(maxi(0, expected_pixel_count))
	var output_pos := 0

	var clear_code := 1 << min_code_size
	var end_code := clear_code + 1

	var dictionary := _fresh_lzw_dictionary(clear_code)
	var next_code := end_code + 1
	var code_size := min_code_size + 1
	var prev_entry := PackedByteArray()

	var byte_pos := 0
	var bit_buffer := 0
	var bit_count := 0

	while true:
		while bit_count < code_size and byte_pos < data.size():
			bit_buffer |= data[byte_pos] << bit_count
			bit_count += 8
			byte_pos += 1
		if bit_count < code_size:
			break

		var code := bit_buffer & ((1 << code_size) - 1)
		bit_buffer >>= code_size
		bit_count -= code_size

		if code == clear_code:
			dictionary = _fresh_lzw_dictionary(clear_code)
			next_code = end_code + 1
			code_size = min_code_size + 1
			prev_entry = PackedByteArray()
			continue
		if code == end_code:
			break

		var entry: PackedByteArray
		if code < next_code:
			entry = dictionary[code]
		elif code == next_code and prev_entry.size() > 0:
			entry = prev_entry.duplicate()
			entry.append(prev_entry[0])
		else:
			break  # corrupt/truncated stream -- stop, keep what decoded so far

		for b in entry:
			if output_pos >= output.size():
				break
			output[output_pos] = b
			output_pos += 1

		if prev_entry.size() > 0 and next_code < 4096:
			var new_entry := prev_entry.duplicate()
			new_entry.append(entry[0])
			if next_code >= dictionary.size():
				dictionary.append(new_entry)
			else:
				dictionary[next_code] = new_entry
			next_code += 1
			if next_code >= (1 << code_size) and code_size < 12:
				code_size += 1

		prev_entry = entry

	return output

static func _blit_frame(canvas: Image, indices: PackedByteArray, left: int, top: int, width: int, height: int, color_table: PackedColorArray, transparent_index: int) -> void:
	var canvas_w := canvas.get_width()
	var canvas_h := canvas.get_height()
	for y in range(height):
		var canvas_y := top + y
		if canvas_y < 0 or canvas_y >= canvas_h:
			continue
		for x in range(width):
			var canvas_x := left + x
			if canvas_x < 0 or canvas_x >= canvas_w:
				continue
			var idx_pos := y * width + x
			if idx_pos >= indices.size():
				continue
			var color_index := indices[idx_pos]
			if color_index == transparent_index or color_index >= color_table.size():
				continue
			canvas.set_pixel(canvas_x, canvas_y, color_table[color_index])

static func _clear_rect(canvas: Image, left: int, top: int, width: int, height: int) -> void:
	var canvas_w := canvas.get_width()
	var canvas_h := canvas.get_height()
	for y in range(height):
		var canvas_y := top + y
		if canvas_y < 0 or canvas_y >= canvas_h:
			continue
		for x in range(width):
			var canvas_x := left + x
			if canvas_x < 0 or canvas_x >= canvas_w:
				continue
			canvas.set_pixel(canvas_x, canvas_y, Color(0, 0, 0, 0))
