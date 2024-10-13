class_name RMQContentHeader
extends RefCounted

var content_class: int
var content_weight: int
var content_body_size: int
var properties : RMQBasicClass.Properties

func _init(content_class:int,content_weight:int,content_body_size:int,properties:RMQBasicClass.Properties):
	self.content_class = content_class
	self.content_weight = content_weight
	self.content_body_size = content_body_size
	self.properties = properties
	
	
func to_frame(channel_number:int) -> RMQFrame:
	var payload_buffer = StreamPeerBuffer.new()
	payload_buffer.big_endian = true
	payload_buffer.put_u16(content_class)
	payload_buffer.put_u16(content_weight)
	payload_buffer.put_u64(content_body_size)
	payload_buffer.put_data(properties.to_bytes())
	return RMQFrame.new(RMQFrame.FrameType.HEADER, channel_number, payload_buffer.data_array)
		

static func from_frame(frame:RMQFrame) -> RMQContentHeader:
	var class_id_parse_result = await RMQParserU16.forward(frame.payload, null, push_error)
	var weight_parse_result = await RMQParserU16.forward(class_id_parse_result.remaining_bytes, null, push_error)
	var body_size_parse_result = await RMQParserU64.forward(weight_parse_result.remaining_bytes, null, push_error)
	
	var properties = null
	if class_id_parse_result.data == 60: # basic class id
		properties = await RMQBasicClass.Properties.from_bytes(body_size_parse_result.remaining_bytes)
		
	return RMQContentHeader.new(class_id_parse_result.data, weight_parse_result.data, body_size_parse_result.data, properties)
	
