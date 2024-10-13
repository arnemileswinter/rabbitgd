class_name RMQParserFloat
extends RefCounted

static func forward(remaining_bytes:PackedByteArray, signal_data, on_error: Callable) -> RMQParseResult:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.data_array = remaining_bytes
	while buffer.get_available_bytes() < 4:
		await RMQParserUtils.wait_for_more_data(buffer, signal_data)
	return RMQParseResult.new(buffer.get_float(), RMQParserUtils.get_remaining_bytes(buffer))
