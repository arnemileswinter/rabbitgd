class_name RMQParserUtils
extends Object

static func wait_for_more_data(buffer: StreamPeerBuffer, signal_data) -> void:
	var more_data = await signal_data
	var old_data = buffer.data_array
	old_data.append_array(more_data)
	buffer.data_array = old_data

static func get_remaining_bytes(buffer) -> PackedByteArray:
	return buffer.data_array.slice(buffer.get_position())
