class_name RMQConfirmClass
extends RefCounted

const CLASS_ID = 85
static func _parse_frame_preconditions(frame:RMQFrame, expected_frame_type: RMQFrame.FrameType, expected_method_id:int) -> RMQParseResult:
	if frame.frame_type != expected_frame_type:
		return RMQParseResult.new(false,frame.payload)
	var class_id_parse_result = await RMQParserU16.forward(frame.payload, null, push_error)
	if class_id_parse_result.data != CLASS_ID:
		return RMQParseResult.new(false,frame.payload)
	var method_id_parse_result = await RMQParserU16.forward(class_id_parse_result.remaining_bytes, null, push_error)
	if method_id_parse_result.data != expected_method_id:
		return RMQParseResult.new(false,class_id_parse_result.remaining_bytes)
	return RMQParseResult.new(true,method_id_parse_result.remaining_bytes)


class Select extends RefCounted:
	const METHOD_ID = 10
	var _no_wait: bool
	
	func _init(no_wait:bool):
		self._no_wait = no_wait
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		RMQEncodePrimitives.put_bits(payload_buffer,[_no_wait])
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class SelectOk extends RefCounted:
	const METHOD_ID = 11
	static func from_frame(frame:RMQFrame) -> SelectOk:
		var preconditions_parse_result = await RMQConfirmClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return SelectOk.new()
