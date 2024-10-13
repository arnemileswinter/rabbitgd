class_name RMQExchangeClass
extends RefCounted

const CLASS_ID = 40
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

class Declare extends RefCounted:
	const METHOD_ID=10
	
	var _exchange:String
	var _type:String
	var _passive:bool
	var _durable:bool
	var _auto_delete:bool
	var _internal:bool
	var _no_wait:bool
	var _arguments:RMQFieldTable
	
	func _init(exchange:String,type:String,passive:bool,durable:bool,auto_delete:bool,internal:bool,no_wait:bool,arguments:RMQFieldTable):
		_exchange = exchange
		_type = type
		_passive = passive
		_durable = durable
		_auto_delete = auto_delete
		_internal = internal
		_no_wait = no_wait
		_arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _exchange)
		RMQEncodePrimitives.put_short_string(payload_buffer, _type)
		RMQEncodePrimitives.put_bits(payload_buffer,[
			_passive,
			_durable,
			_auto_delete,
			_internal,
			_no_wait
			])
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class DeclareOk extends RefCounted:
	const METHOD_ID=11
	
	static func from_frame(frame:RMQFrame) -> DeclareOk:
		var preconditions_parse_result = await RMQExchangeClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return DeclareOk.new()

class Delete extends RefCounted:
	const METHOD_ID=20
	
	var _exchange:String
	var _if_unused:bool
	var _no_wait:bool
	
	func _init(exchange:String,if_unused:bool,no_wait:bool):
		_exchange = exchange
		_if_unused = if_unused
		_no_wait = no_wait
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _exchange)
		RMQEncodePrimitives.put_bits(payload_buffer,[
			_if_unused,
			_no_wait
			])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class DeleteOk extends RefCounted:
	const METHOD_ID=21
	
	static func from_frame(frame:RMQFrame) -> DeleteOk:
		var preconditions_parse_result = await RMQExchangeClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return DeleteOk.new()


class Bind extends RefCounted:
	const METHOD_ID=30
	var _destination:String
	var _source:String
	var _routing_key:String
	var _no_wait:bool
	var _arguments:RMQFieldTable
	
	func _init(destination:String,source:String,routing_key:String,no_wait:bool,arguments:RMQFieldTable):
		self._destination = destination
		self._source = source
		self._routing_key = routing_key
		self._no_wait = no_wait
		self._arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer,_destination)
		RMQEncodePrimitives.put_short_string(payload_buffer,_source)
		RMQEncodePrimitives.put_short_string(payload_buffer,_routing_key)
		RMQEncodePrimitives.put_bits(payload_buffer,[_no_wait])
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class BindOk extends RefCounted:
	const METHOD_ID=31
	
	static func from_frame(frame:RMQFrame) -> BindOk:
		var preconditions_parse_result = await RMQExchangeClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return BindOk.new()


class Unbind extends RefCounted:
	const METHOD_ID=40
	var _destination:String
	var _source:String
	var _routing_key:String
	var _no_wait:bool
	var _arguments:RMQFieldTable
	
	func _init(destination:String,source:String,routing_key:String,no_wait:bool,arguments:RMQFieldTable):
		self._destination = destination
		self._source = source
		self._routing_key = routing_key
		self._no_wait = no_wait
		self._arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer,_destination)
		RMQEncodePrimitives.put_short_string(payload_buffer,_source)
		RMQEncodePrimitives.put_short_string(payload_buffer,_routing_key)
		RMQEncodePrimitives.put_bits(payload_buffer,[_no_wait])
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class UnbindOk extends RefCounted:
	const METHOD_ID=51
	
	static func from_frame(frame:RMQFrame) -> UnbindOk:
		var preconditions_parse_result = await RMQExchangeClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return UnbindOk.new()
