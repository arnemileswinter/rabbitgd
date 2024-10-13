class_name RMQBasicClass
extends RefCounted

const CLASS_ID = 60
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


class Qos extends RefCounted:
	const METHOD_ID = 10
	var prefetch_size:int
	var prefetch_count:int
	var global:int
	
	func _init(prefetch_size:int,prefetch_count:int,global:bool):
		self.prefetch_size=prefetch_size
		self.prefetch_count=prefetch_count
		self.global=global

	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u32(prefetch_size)
		payload_buffer.put_u16(prefetch_count)
		RMQEncodePrimitives.put_bits(payload_buffer,[global])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class QosOk extends RefCounted:
	const METHOD_ID = 11
	
	static func from_frame(frame:RMQFrame) -> QosOk:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return QosOk.new()

class Consume extends RefCounted:
	const METHOD_ID=20
	var _queue:String
	var _consumer_tag:String
	var _no_local:bool
	var _no_ack:bool
	var _exclusive:bool
	var _no_wait:bool
	var _arguments:RMQFieldTable
	
	func _init(
		queue:String,
		consumer_tag:String,
		no_local:bool,
		no_ack:bool,
		exclusive:bool,
		no_wait:bool,
		arguments:RMQFieldTable
	):
		self._queue = queue
		self._consumer_tag = consumer_tag
		self._no_local = no_local
		self._no_ack = no_ack
		self._exclusive = exclusive
		self._no_wait = no_wait
		self._arguments = arguments
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer,_queue)
		RMQEncodePrimitives.put_short_string(payload_buffer,_consumer_tag)
		RMQEncodePrimitives.put_bits(payload_buffer, [_no_local, _no_ack, _exclusive, _no_wait])
		RMQEncodePrimitives.put_table(payload_buffer, _arguments)
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class ConsumeOk extends RefCounted:
	const METHOD_ID=21
	var consumer_tag:String
	
	func _init(consumer_tag:String):
		self.consumer_tag = consumer_tag
		
	static func from_frame(frame:RMQFrame) -> ConsumeOk:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var active_parse_result = await RMQParserShortString.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return ConsumeOk.new(active_parse_result.data)


class Cancel extends RefCounted:
	const METHOD_ID=30
	var _consumer_tag:String
	var _no_wait:bool
	
	func _init(
		consumer_tag:String,
		no_wait:bool
	):
		self._consumer_tag = consumer_tag
		self._no_wait = no_wait
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_short_string(payload_buffer,_consumer_tag)
		RMQEncodePrimitives.put_bits(payload_buffer, [_no_wait])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class CancelOk extends RefCounted:
	const METHOD_ID=31
	var consumer_tag:String
	
	func _init(consumer_tag:String):
		self.consumer_tag = consumer_tag
		
	static func from_frame(frame:RMQFrame) -> CancelOk:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var active_parse_result = await RMQParserShortString.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return CancelOk.new(active_parse_result.data)


class Publish extends RefCounted:
	const METHOD_ID=40
	var _exchange:String
	var _routing_key:String
	var _mandatory:bool
	var _immediate:bool
	
	func _init(
		exchange:String,
		routing_key:String,
		mandatory:bool,
		immediate:bool
	):
		self._exchange=exchange
		self._routing_key=routing_key
		self._mandatory=mandatory
		self._immediate=immediate
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer,_exchange)
		RMQEncodePrimitives.put_short_string(payload_buffer,_routing_key)
		RMQEncodePrimitives.put_bits(payload_buffer, [_mandatory,_immediate])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class Return extends RefCounted:
	const METHOD_ID = 50
	var reply_code:int
	var reply_text:String
	var exchange:String
	var routing_key:String
	
	func _init(reply_code:int,reply_text:String,exchange:String,routing_key:String):
		self.reply_code=reply_code
		self.reply_text=reply_text
		self.exchange=exchange
		self.routing_key=routing_key
	
	static func from_frame(frame: RMQFrame) -> Return:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var reply_code_parse_result = await RMQParserU16.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var reply_text_parse_result = await RMQParserShortString.forward(reply_code_parse_result.remaining_bytes, null, push_error)
		var exchange_parse_result = await RMQParserShortString.forward(reply_text_parse_result.remaining_bytes, null, push_error)
		var routing_key_parse_result = await RMQParserShortString.forward(exchange_parse_result.remaining_bytes, null, push_error)
		return Return.new(
			reply_code_parse_result.data,
			reply_text_parse_result.data,
			exchange_parse_result.data,
			routing_key_parse_result.data)


class Deliver extends RefCounted:
	const METHOD_ID = 60
	var consumer_tag:String
	var delivery_tag:int
	var redelivered:bool
	var exchange:String
	var routing_key:String
	
	func _init(consumer_tag:String,delivery_tag:int,redelivered:bool,exchange:String,routing_key:String):
		self.consumer_tag = consumer_tag
		self.delivery_tag = delivery_tag
		self.redelivered = redelivered
		self.exchange = exchange
		self.routing_key = routing_key
	
	static func from_frame(frame: RMQFrame) -> Deliver:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var consumer_tag_parse_result = await RMQParserShortString.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var delivery_tag_parse_result = await RMQParserU64.forward(consumer_tag_parse_result.remaining_bytes, null, push_error)
		var redelivered_parse_result = await RMQParserU8.forward(delivery_tag_parse_result.remaining_bytes, null, push_error)
		var exchange_parse_result = await RMQParserShortString.forward(redelivered_parse_result.remaining_bytes, null, push_error)
		var routing_key_parse_result = await RMQParserShortString.forward(exchange_parse_result.remaining_bytes, null, push_error)
		
		return Deliver.new(
			consumer_tag_parse_result.data,
			delivery_tag_parse_result.data,
			redelivered_parse_result.data != 0,
			exchange_parse_result.data,
			routing_key_parse_result.data)

class Get extends RefCounted:
	const METHOD_ID=70
	var _queue:String
	var _no_ack:bool
	
	func _init(
		queue:String,
		no_ack:bool
	):
		self._queue = queue
		self._no_ack = no_ack
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u16(0) # reserved 1
		RMQEncodePrimitives.put_short_string(payload_buffer,_queue)
		RMQEncodePrimitives.put_bits(payload_buffer, [_no_ack])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class GetOk extends RefCounted:
	const METHOD_ID = 71
	var delivery_tag:int
	var redelivered:bool
	var exchange:String
	var routing_key:String
	var message_count:int
	
	func _init(delivery_tag:int,redelivered:bool,exchange:String,routing_key:String,message_count:int):
		self.delivery_tag = delivery_tag
		self.redelivered = redelivered
		self.exchange = exchange
		self.routing_key = routing_key
		self.message_count = message_count
	
	static func from_frame(frame: RMQFrame) -> GetOk:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var delivery_tag_parse_result = await RMQParserU64.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var redelivered_parse_result = await RMQParserU8.forward(delivery_tag_parse_result.remaining_bytes, null, push_error)
		var exchange_parse_result = await RMQParserShortString.forward(redelivered_parse_result.remaining_bytes, null, push_error)
		var routing_key_parse_result = await RMQParserShortString.forward(exchange_parse_result.remaining_bytes, null, push_error)
		var message_count_parse_result = await RMQParserU32.forward(routing_key_parse_result.remaining_bytes, null, push_error)

		return GetOk.new(
			delivery_tag_parse_result.data,
			redelivered_parse_result.data != 0,
			exchange_parse_result.data,
			routing_key_parse_result.data,
			message_count_parse_result.data)


class GetEmpty extends RefCounted:
	const METHOD_ID=72
		
	static func from_frame(frame:RMQFrame) -> GetEmpty:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		await RMQParserShortString.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		return GetEmpty.new()


class Ack extends RefCounted:
	const METHOD_ID = 80
	var delivery_tag:int
	var multiple:bool
	
	func _init(delivery_tag:int,multiple:bool):
		self.delivery_tag = delivery_tag
		self.multiple=multiple
	
	static func from_frame(frame:RMQFrame) -> Ack:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var delivery_tag_parse_result = await RMQParserU64.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var multiple_parse_result = await RMQParserU8.forward(delivery_tag_parse_result.remaining_bytes,null, push_error)
		
		return Ack.new(delivery_tag_parse_result.data, multiple_parse_result.data != 0)
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u64(delivery_tag)
		RMQEncodePrimitives.put_bits(payload_buffer, [multiple])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class Reject extends RefCounted:
	const METHOD_ID=90
	var delivery_tag:int
	var requeue:bool
	
	func _init(delivery_tag:int,requeue:bool):
		self.delivery_tag = delivery_tag
		self.requeue=requeue
		
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u32(delivery_tag)
		RMQEncodePrimitives.put_bits(payload_buffer, [requeue])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class Nack extends RefCounted:
	const METHOD_ID=120
	var delivery_tag:int
	var multiple:bool
	var requeue:bool
	
	func _init(delivery_tag:int,multiple:bool,requeue:bool):
		self.delivery_tag = delivery_tag
		self.multiple=multiple
		self.requeue=requeue
	
	static func from_frame(frame:RMQFrame) -> Nack:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		var delivery_tag_parse_result = await RMQParserU64.forward(preconditions_parse_result.remaining_bytes, null, push_error)
		var bits_parse_result = await RMQParserU8.forward(delivery_tag_parse_result.remaining_bytes,null, push_error)
		
		var multiple = (bits_parse_result & 1) != 0
		var requeue = (bits_parse_result & 2) != 0
		
		return Nack.new(delivery_tag_parse_result.data, multiple,requeue)
	
	
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		payload_buffer.put_u64(delivery_tag)
		RMQEncodePrimitives.put_bits(payload_buffer, [multiple,requeue])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class RecoverAsync extends RefCounted:
	const METHOD_ID=100
	var requeue:bool
	
	func _init(requeue:bool):
		self.requeue=requeue
		
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_bits(payload_buffer, [requeue])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class Recover extends RefCounted:
	const METHOD_ID=110
	var requeue:bool
	
	func _init(requeue:bool):
		self.requeue=requeue
		
	func to_frame(channel_number:int) -> RMQFrame:
		var payload_buffer = StreamPeerBuffer.new()
		payload_buffer.big_endian = true
		
		payload_buffer.put_u16(CLASS_ID)
		payload_buffer.put_u16(METHOD_ID)
		
		RMQEncodePrimitives.put_bits(payload_buffer, [requeue])
		
		return RMQFrame.new(RMQFrame.FrameType.METHOD, channel_number, payload_buffer.data_array)


class RecoverOk extends RefCounted:
	const METHOD_ID = 111
	
	static func from_frame(frame:RMQFrame) -> RecoverOk:
		var preconditions_parse_result = await RMQBasicClass._parse_frame_preconditions(frame,RMQFrame.FrameType.METHOD,METHOD_ID)
		if not preconditions_parse_result.data:
			return null
		return RecoverOk.new()

class Properties extends RefCounted:
	var _has_property_content_type:bool
	var _has_property_content_encoding:bool
	var _has_property_basic_headers:bool
	var _has_property_delivery_mode:bool
	var _has_property_priority:bool
	var _has_property_correlation_id:bool
	var _has_property_reply_to:bool
	var _has_property_expiration:bool
	var _has_property_message_id:bool
	var _has_property_timestamp:bool
	var _has_property_type:bool
	var _has_property_user_id:bool
	var _has_property_app_id:bool
	var _has_property_reserved:bool

	var _content_type : String = ""
	var _content_encoding : String = ""
	var _headers : RMQFieldTable
	var _delivery_mode : int = 0
	var _priority : int = 0
	var _correlation_id : String = ""
	var _reply_to : String = ""
	var _expiration : String = ""
	var _message_id : String = ""
	var _timestamp : int = 0
	var _type : String = ""
	var _user_id : String = ""
	var _app_id : String = ""
	var _reserved : String = ""
	
	func to_bytes() -> PackedByteArray:
		var peer = StreamPeerBuffer.new()
		peer.big_endian = true
		
		var property_flags:int = 0
		for property_flag in [
			_has_property_content_type,
			_has_property_content_encoding,
			_has_property_basic_headers,
			_has_property_delivery_mode,
			_has_property_priority,
			_has_property_correlation_id,
			_has_property_reply_to,
			_has_property_expiration,
			_has_property_message_id,
			_has_property_timestamp,
			_has_property_type,
			_has_property_user_id,
			_has_property_app_id,
			_has_property_reserved
		]:
			if property_flag:
				property_flags |= 1
			property_flags <<= 1
		peer.put_u16(property_flags)
		
		if _has_property_content_type:
			RMQEncodePrimitives.put_short_string(peer,_content_type)
		if _has_property_content_encoding:
			RMQEncodePrimitives.put_short_string(peer,_content_encoding)
		if _has_property_basic_headers:
			RMQEncodePrimitives._put_field_table(peer,_headers)
		if _has_property_delivery_mode:
			peer.put_u8(_delivery_mode)
		if _has_property_priority:
			peer.put_u8(_priority)
		if _has_property_correlation_id:
			RMQEncodePrimitives.put_short_string(peer,_correlation_id)
		if _has_property_reply_to:
			RMQEncodePrimitives.put_short_string(peer,_reply_to)
		if _has_property_expiration:
			RMQEncodePrimitives.put_short_string(peer,_expiration)
		if _has_property_message_id:
			RMQEncodePrimitives.put_short_string(peer,_message_id)
		if _has_property_timestamp:
			peer.put_u64(_timestamp)
		if _has_property_type:
			RMQEncodePrimitives.put_short_string(peer,_type)
		if _has_property_user_id:
			RMQEncodePrimitives.put_short_string(peer,_user_id)
		if _has_property_app_id:
			RMQEncodePrimitives.put_short_string(peer,_app_id)
		if _has_property_reserved:
			RMQEncodePrimitives.put_short_string(peer,_reserved) # reserved 1 should be empty
		
		return peer.data_array
	
	static func from_bytes(data:PackedByteArray) -> Properties:
		var peer = StreamPeerBuffer.new()
		peer.big_endian = true
		peer.data_array = data
		
		var properties = Properties.new()
		
		var property_flags = peer.get_u16()
		if property_flags % 2 != 0:
			print("[rabbitmq] basic properties has more than 15 flags")
			return null
		
		properties._has_property_content_type = 0 != property_flags & (1 << 15)
		properties._has_property_content_encoding = 0 != property_flags & (1 << 14)
		properties._has_property_basic_headers = 0 != property_flags & (1 << 13)
		properties._has_property_delivery_mode = 0 != property_flags & (1 << 12)
		properties._has_property_priority = 0 != property_flags & (1 << 11)
		properties._has_property_correlation_id = 0 != property_flags & (1 << 10)
		properties._has_property_reply_to = 0 != property_flags & (1 << 9)
		properties._has_property_expiration = 0 != property_flags & (1 << 8)
		properties._has_property_message_id = 0 != property_flags & (1 << 7)
		properties._has_property_timestamp = 0 != property_flags & (1 << 6)
		properties._has_property_type = 0 != property_flags & (1 << 5)
		properties._has_property_user_id = 0 != property_flags & (1 << 4)
		properties._has_property_app_id = 0 != property_flags & (1 << 3)
		properties._has_property_reserved = 0 != property_flags & (1 << 2)
		
		if properties._has_property_reserved:
			print("[rabbitmq] reserved property not 0!")
			return null
		
		var remaining_bytes = RMQParserUtils.get_remaining_bytes(peer)
		if properties._has_property_content_type:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._content_type = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_content_encoding:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._content_encoding = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_basic_headers:
			var parse_result = await RMQParserFieldTable.forward(remaining_bytes, null, push_error)
			properties._headers = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_delivery_mode:
			var parse_result = await RMQParserU8.forward(remaining_bytes, null, push_error)
			properties._delivery_mode = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_priority:
			var parse_result = await RMQParserU8.forward(remaining_bytes, null, push_error)
			properties._priority = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_correlation_id:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._correlation_id = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_reply_to:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._reply_to = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_expiration:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._expiration = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_message_id:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._message_id = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_timestamp:
			var parse_result = await RMQParserU64.forward(remaining_bytes, null, push_error)
			properties._timestamp = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_type:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._type = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_user_id:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._user_id = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_app_id:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._app_id = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
		if properties._has_property_reserved:
			var parse_result = await RMQParserShortString.forward(remaining_bytes, null, push_error)
			properties._reserved = parse_result.data
			remaining_bytes = parse_result.remaining_bytes
	
		return properties

	# content_type
	func get_content_type() -> String:
		return _content_type

	func set_content_type(value: String) -> void:
		_content_type = value
		_has_property_content_type = true

	func has_content_type() -> bool:
		return _has_property_content_type

	# content_encoding
	func get_content_encoding() -> String:
		return _content_encoding

	func set_content_encoding(value: String) -> void:
		_content_encoding = value
		_has_property_content_encoding = true

	func has_content_encoding() -> bool:
		return _has_property_content_encoding

	# headers (basic_headers)
	func get_headers() -> RMQFieldTable:
		return _headers

	func set_headers(value: RMQFieldTable) -> void:
		_headers = value
		_has_property_basic_headers = true

	func has_headers() -> bool:
		return _has_property_basic_headers

	# delivery_mode
	func get_delivery_mode() -> int:
		return _delivery_mode

	func set_delivery_mode(value: int) -> void:
		_delivery_mode = value
		_has_property_delivery_mode = true

	func has_delivery_mode() -> bool:
		return _has_property_delivery_mode

	# priority
	func get_priority() -> int:
		return _priority

	func set_priority(value: int) -> void:
		_priority = value
		_has_property_priority = true

	func has_priority() -> bool:
		return _has_property_priority

	# correlation_id
	func get_correlation_id() -> String:
		return _correlation_id

	func set_correlation_id(value: String) -> void:
		_correlation_id = value
		_has_property_correlation_id = true

	func has_correlation_id() -> bool:
		return _has_property_correlation_id

	# reply_to
	func get_reply_to() -> String:
		return _reply_to

	func set_reply_to(value: String) -> void:
		_reply_to = value
		_has_property_reply_to = true

	func has_reply_to() -> bool:
		return _has_property_reply_to

	# expiration
	func get_expiration() -> String:
		return _expiration

	func set_expiration(value: String) -> void:
		_expiration = value
		_has_property_expiration = true

	func has_expiration() -> bool:
		return _has_property_expiration

	# message_id
	func get_message_id() -> String:
		return _message_id

	func set_message_id(value: String) -> void:
		_message_id = value
		_has_property_message_id = true

	func has_message_id() -> bool:
		return _has_property_message_id

	# timestamp
	func get_timestamp() -> int:
		return _timestamp

	func set_timestamp(value: int) -> void:
		_timestamp = value
		_has_property_timestamp = true

	func has_timestamp() -> bool:
		return _has_property_timestamp

	# type
	func get_type() -> String:
		return _type

	func set_type(value: String) -> void:
		_type = value
		_has_property_type = true

	func has_type() -> bool:
		return _has_property_type

	# user_id
	func get_user_id() -> String:
		return _user_id

	func set_user_id(value: String) -> void:
		_user_id = value
		_has_property_user_id = true

	func has_user_id() -> bool:
		return _has_property_user_id

	# app_id
	func get_app_id() -> String:
		return _app_id

	func set_app_id(value: String) -> void:
		_app_id = value
		_has_property_app_id = true

	func has_app_id() -> bool:
		return _has_property_app_id
