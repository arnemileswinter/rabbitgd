class_name RMQChannelClass
extends RefCounted

const CLASS_ID = 20
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

class Open extends RefCounted:
	const METHOD_ID = 10

	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_short_string(payload_buffer, "") # reserved 1
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class OpenOk extends RefCounted:
	const METHOD_ID = 11
	
	static func from_frame(frame:RMQFrame) -> OpenOk:
		var preconditions_parse_result = await RMQChannelClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return OpenOk.new()


class Flow extends RefCounted:
	const METHOD_ID = 20
	var active:bool
	
	func _init(active:bool):
		self.active = active

	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_bits(payload_buffer, [active])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)
	
	
	static func from_frame(frame:RMQFrame) -> Flow:
		var preconditions_parse_result = await RMQChannelClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var active_parse_result = await RMQParserU8.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return Flow.new(active_parse_result.data != 0)

class FlowOk extends RefCounted:
	const METHOD_ID = 21
	var active:bool
	
	func _init(active:bool):
		self.active = active
	
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_bits(payload_buffer, [active])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)
	
	static func from_frame(frame:RMQFrame) -> FlowOk:
		var preconditions_parse_result = await RMQChannelClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var active_parse_result = await RMQParserU8.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return FlowOk.new(active_parse_result.data != 0)


class Close extends RefCounted:
	const METHOD_ID = 40
	var reply_code:int
	var reply_text:String
	var class_id:int
	var method_id:int
	
	func _init(reply_code:int,	reply_text:String,	class_id:int,	method_id:int):
		self.reply_code=reply_code
		self.reply_text=reply_text
		self.class_id=class_id
		self.method_id=method_id
	
	static func from_frame(frame: RMQFrame) -> Close:
		var preconditions_parse_result = await RMQChannelClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var reply_code_parse_result = await RMQParserU16.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var reply_text_parse_result = await RMQParserShortString.forward(reply_code_parse_result.remaining_bytes, null, push_error)
		var class_id_parse_result = await RMQParserU16.forward(reply_text_parse_result.remaining_bytes, null, push_error)
		var method_id_parse_result = await RMQParserU16.forward(class_id_parse_result.remaining_bytes, null, push_error)
		return Close.new(reply_code_parse_result.data,reply_text_parse_result.data,class_id_parse_result.data,method_id_parse_result.data)
	
	func to_frame(channel_number:int) -> RMQFrame:	
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(reply_code)
		RMQEncodePrimitives.put_short_string(payload_buffer,reply_text)
		payload_buffer.put_u16(class_id)
		payload_buffer.put_u16(method_id)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class CloseOk extends RefCounted:
	const METHOD_ID=41
	
	static func from_frame(frame:RMQFrame) -> CloseOk:
		var preconditions_parse_result = await RMQChannelClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return CloseOk.new()

	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)
