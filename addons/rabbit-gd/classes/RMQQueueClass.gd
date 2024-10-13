class_name RMQQueueClass
extends RefCounted

const CLASS_ID = 50
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
	const METHOD_ID = 10
	
	var _queue: String
	var _passive: bool
	var _durable: bool
	var _exclusive: bool
	var _auto_delete: bool
	var _no_wait: bool
	var _arguments:RMQFieldTable

	func _init(queue:String,passive:bool,durable:bool,exclusive:bool,no_wait:bool,arguments:RMQFieldTable):
		_queue = queue
		_passive = passive
		_durable = durable
		_exclusive = exclusive
		_no_wait = no_wait
		_arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _queue)
		RMQEncodePrimitives.put_bits(payload_buffer,[
			_passive,
			_durable,
			_exclusive,
			_auto_delete,
			_no_wait
			])
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class DeclareOk extends RefCounted:
	const METHOD_ID=11
	
	var queue: String
	var message_count: int
	var consumer_count: int
	
	func _init(queue:String,message_count:int,consumer_count:int):
		self.queue = queue
		self.message_count = message_count
		self.consumer_count = consumer_count
	
	static func from_frame(frame:RMQFrame) -> DeclareOk:
		var preconditions_parse_result = await RMQQueueClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var queue_name_parse_result = await RMQParserShortString.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var message_count_parse_result = await RMQParserU32.forward(queue_name_parse_result.remaining_bytes, null, push_error)
		var consumer_count_parse_result = await RMQParserU32.forward(message_count_parse_result.remaining_bytes, null, push_error)
	
		return DeclareOk.new(queue_name_parse_result.data, message_count_parse_result.data, consumer_count_parse_result.data)


class Bind extends RefCounted:
	const METHOD_ID = 20
	
	var _queue: String
	var _exchange: String
	var _routing_key: String
	var _no_wait: bool
	var _arguments:RMQFieldTable

	func _init(queue:String,exchange:String,routing_key:String,no_wait:bool,arguments:RMQFieldTable):
		_queue = queue
		_exchange = exchange
		_routing_key = routing_key
		_no_wait = no_wait
		_arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _queue)
		RMQEncodePrimitives.put_short_string(payload_buffer, _exchange)
		RMQEncodePrimitives.put_short_string(payload_buffer, _routing_key)
		RMQEncodePrimitives.put_bits(payload_buffer, [_no_wait])
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class BindOk extends RefCounted:
	const METHOD_ID=21
	
	static func from_frame(frame:RMQFrame) -> BindOk:
		var preconditions_parse_result = await RMQQueueClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null

		return BindOk.new()


class Unbind extends RefCounted:
	const METHOD_ID = 50
	
	var _queue: String
	var _exchange: String
	var _routing_key: String
	var _arguments:RMQFieldTable

	func _init(queue:String,exchange:String,routing_key:String,arguments:RMQFieldTable):
		_queue = queue
		_exchange = exchange
		_routing_key = routing_key
		_arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _queue)
		RMQEncodePrimitives.put_short_string(payload_buffer, _exchange)
		RMQEncodePrimitives.put_short_string(payload_buffer, _routing_key)
		RMQEncodePrimitives.put_table(payload_buffer,_arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class UnbindOk extends RefCounted:
	const METHOD_ID=51
	
	static func from_frame(frame:RMQFrame) -> UnbindOk:
		var preconditions_parse_result = await RMQQueueClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null

		return UnbindOk.new()

class Purge extends RefCounted:
	const METHOD_ID = 30
	
	var _queue: String
	var _no_wait:bool

	func _init(queue:String,no_wait:bool):
		_queue = queue
		_no_wait = no_wait
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _queue)
		RMQEncodePrimitives.put_bits(payload_buffer,[_no_wait])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class PurgeOk extends RefCounted:
	const METHOD_ID=31
	
	var message_count: int
	
	func _init(message_count:int):
		self.message_count = message_count
	
	static func from_frame(frame:RMQFrame) -> PurgeOk:
		var preconditions_parse_result = await RMQQueueClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var message_count_parse_result = await RMQParserU32.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return PurgeOk.new(message_count_parse_result.data)


class Delete extends RefCounted:
	const METHOD_ID = 40
	
	var _queue: String
	var _if_unused:bool
	var _if_empty:bool
	var _no_wait:bool

	func _init(queue:String,if_unused:bool,if_empty:bool,no_wait:bool):
		_queue = queue
		_if_unused = if_unused
		_if_empty = if_empty
		_no_wait = no_wait
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer, _queue)
		RMQEncodePrimitives.put_bits(payload_buffer, [
			_if_unused,
			_if_empty,
			_no_wait
		])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)

class DeleteOk extends RefCounted:
	const METHOD_ID=41
	
	var message_count: int
	
	func _init(message_count:int):
		self.message_count = message_count
	
	static func from_frame(frame:RMQFrame) -> DeleteOk:
		var preconditions_parse_result = await RMQQueueClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var message_count_parse_result = await RMQParserU32.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return DeleteOk.new(message_count_parse_result.data)
