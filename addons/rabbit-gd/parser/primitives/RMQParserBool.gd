class_name RMQParserBool
extends RefCounted

static func forward(remaining_bytes:PackedByteArray, signal_data, on_error: Callable) -> RMQParseResult:
	var result = await RMQParserU8.forward(remaining_bytes,signal_data,on_error)
	return RMQParseResult.new(result.data!=0, result.remaining_bytes)
