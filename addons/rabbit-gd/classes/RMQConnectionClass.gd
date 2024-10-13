class_name RMQConnectionClass
extends RefCounted

const CLASS_ID = 10
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

class Start extends RefCounted:
	const METHOD_ID = 10
	var version_minor:int
	var version_major:int
	var server_properties:RMQFieldTable
	var mechanisms:String
	var locales:String
	
	func _init(version_minor:int,version_major:int,server_properties:RMQFieldTable,mechanisms:String,locales:String):
		self.version_minor=version_minor
		self.version_major=version_major
		self.server_properties=server_properties
		self.mechanisms=mechanisms
		self.locales=locales
	
	static func from_frame(frame: RMQFrame) -> Start:
		var preconditions_parse_result = await RMQConnectionClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var version_minor_parse_result = await RMQParserU8.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var version_major_parse_result = await RMQParserU8.forward(version_minor_parse_result.remaining_bytes, null, push_error)
		var server_properties_parse_result = await RMQParserFieldTable.forward(version_major_parse_result.remaining_bytes, null, push_error)
		var mechanisms_parse_result = await RMQParserLongString.forward(server_properties_parse_result.remaining_bytes, null, push_error)
		var locales_parse_result = await RMQParserLongString.forward(mechanisms_parse_result.remaining_bytes, null, push_error)
		return Start.new(
			version_minor_parse_result.data,version_major_parse_result.data,
			server_properties_parse_result.data,
			mechanisms_parse_result.data.get_string_from_utf8(),
			locales_parse_result.data.get_string_from_utf8()
			)

class StartOk extends RefCounted:
	const METHOD_ID = 11
	
	var username : String
	var password : String
	
	func _init(username:String,password:String):
		self.username = username
		self.password = password
	
	func to_frame() -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		var client_properties := RMQFieldTable.new()
		client_properties.put_long_string("product", ProjectSettings['application/config/name'].to_utf8_buffer())
		client_properties.put_long_string("information", "godot".to_utf8_buffer())
		client_properties.put_long_string("platform", OS.get_name().to_utf8_buffer())
		RMQEncodePrimitives.put_table(payload_buffer, client_properties)
		# mechanism
		RMQEncodePrimitives.put_short_string(payload_buffer, "PLAIN")
		
		var response = PackedByteArray()
		response.append(0)
		response.append_array(username.to_utf8_buffer())
		response.append(0)
		response.append_array(password.to_utf8_buffer())
		RMQEncodePrimitives.put_long_string(payload_buffer, response)
		# locale
		RMQEncodePrimitives.put_short_string(payload_buffer, "en_US")
		return RMQFrame.new(RMQFrame.FrameType.METHOD, 0, payload_buffer.data_array)

class Tune extends RefCounted:
	const METHOD_ID = 30
	var channel_max:int
	var frame_max:int
	var heartbeat:int
	
	func _init(channel_max:int,frame_max:int,heartbeat:int):
		self.channel_max=channel_max
		self.frame_max=frame_max
		self.heartbeat=heartbeat
	
	static func from_frame(frame: RMQFrame) -> Tune:
		var preconditions_parse_result = await RMQConnectionClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var channel_max_parse_result = await RMQParserU16.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var frame_max_parse_result = await RMQParserU32.forward(channel_max_parse_result.remaining_bytes, null, push_error)
		var heartbeat_parse_result = await RMQParserU16.forward(frame_max_parse_result.remaining_bytes, null, push_error)
		return Tune.new(channel_max_parse_result.data,frame_max_parse_result.data,heartbeat_parse_result.data)

class TuneOk extends RefCounted:
	const METHOD_ID = 31
	var channel_max: int
	var frame_max: int
	var heartbeat: int
	
	func _init(channel_max: int, frame_max: int, heartbeat: int):
		self.channel_max = channel_max
		self.frame_max = frame_max
		self.heartbeat = heartbeat
		
	func to_frame() -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(channel_max)
		payload_buffer.put_u32(frame_max)
		payload_buffer.put_u16(heartbeat)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, 0, payload_buffer.data_array)

class Open extends RefCounted:
	const METHOD_ID = 40
	var vhost: String
	
	func _init(vhost:String):
		self.vhost = vhost
	
	func to_frame() -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_short_string(payload_buffer, vhost)
		RMQEncodePrimitives.put_short_string(payload_buffer, "") # reserved 1
		payload_buffer.put_u8(0) # reserved 2
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, 0, payload_buffer.data_array)

class OpenOk extends RefCounted:
	const METHOD_ID=41
	
	static func from_frame(frame:RMQFrame) -> OpenOk:
		var preconditions_parse_result = await RMQConnectionClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return OpenOk.new()

class Close extends RefCounted:
	const METHOD_ID = 50
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
		var preconditions_parse_result = await RMQConnectionClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var reply_code_parse_result = await RMQParserU16.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var reply_text_parse_result = await RMQParserShortString.forward(reply_code_parse_result.remaining_bytes, null, push_error)
		var class_id_parse_result = await RMQParserU16.forward(reply_text_parse_result.remaining_bytes, null, push_error)
		var method_id_parse_result = await RMQParserU16.forward(class_id_parse_result.remaining_bytes, null, push_error)
		return Close.new(reply_code_parse_result.data,reply_text_parse_result.data,class_id_parse_result.data,method_id_parse_result.data)
	
	func to_frame() -> RMQFrame:	
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(reply_code)
		RMQEncodePrimitives.put_short_string(payload_buffer,reply_text)
		payload_buffer.put_u16(class_id)
		payload_buffer.put_u16(method_id)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, 0, payload_buffer.data_array)

class CloseOk extends RefCounted:
	const METHOD_ID=51
	
	static func from_frame(frame:RMQFrame) -> CloseOk:
		var preconditions_parse_result = await RMQConnectionClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return CloseOk.new()

	func to_frame() -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		return RMQFrame.new(RMQFrame.FrameType.METHOD, 0, payload_buffer.data_array)
