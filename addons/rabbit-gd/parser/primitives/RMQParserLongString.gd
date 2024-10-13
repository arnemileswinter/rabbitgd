class_name RMQParserLongString
extends RefCounted

static func forward(remaining_bytes_0:PackedByteArray,signal_data, on_error: Callable) -> RMQParseResult:
	var parse_result_u32 = await RMQParserU32.forward(remaining_bytes_0,signal_data, on_error)
	var size = parse_result_u32.data
	
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.data_array = parse_result_u32.remaining_bytes
	
	while buffer.get_available_bytes() < size:
		await RMQParserUtils.wait_for_more_data(buffer, signal_data)

	var pdata = buffer.get_data(size)
	if pdata[0] != OK:
		return on_error.call("error code parsing long string {}" % pdata[0])
	else:
		return RMQParseResult.new(pdata[1], RMQParserUtils.get_remaining_bytes(buffer))
