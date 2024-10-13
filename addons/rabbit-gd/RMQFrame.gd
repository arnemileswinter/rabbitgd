class_name RMQFrame
extends RefCounted

const FRAME_END = 0xCE
enum FrameType {
	METHOD = 1,
	HEADER = 2,
	BODY = 3,
	HEARTBEAT = 8
}

var frame_type : FrameType
var channel_number : int
var payload : PackedByteArray

func _init(frame_type : FrameType, channel_number : int, payload : PackedByteArray):
	self.frame_type=frame_type
	self.channel_number=channel_number
	self.payload=payload

func to_wire() -> PackedByteArray:
	var frame_buffer = StreamPeerBuffer.new()
	frame_buffer.big_endian = true
	frame_buffer.put_u8(frame_type)
	frame_buffer.put_u16(channel_number)
	RMQEncodePrimitives.put_long_string(frame_buffer,payload)
	frame_buffer.put_u8(FRAME_END)
	return frame_buffer.data_array

static func forward(remaining_bytes:PackedByteArray, signal_data, on_error: Callable) -> RMQParseResult:
	var frame_type_parse_result = await RMQParserU8.forward(remaining_bytes, signal_data, on_error) # frame type
	var channel_number_parse_result = await RMQParserU16.forward(frame_type_parse_result.remaining_bytes, signal_data, on_error) # channel no
	var payload_bytes_parse_result = await RMQParserLongString.forward(channel_number_parse_result.remaining_bytes,signal_data,on_error) # payload
	var eof_parse_result = await RMQParserU8.forward(payload_bytes_parse_result.remaining_bytes,signal_data,on_error)
		
	if eof_parse_result.data != FRAME_END:
		return on_error.call("bad end of frame!")

	if not FrameType.values().has(frame_type_parse_result.data):
		return on_error.call("unknown frame_type ", frame_type_parse_result.data)
	
	return RMQParseResult.new(RMQFrame.new(
		frame_type_parse_result.data,
		channel_number_parse_result.data,
		payload_bytes_parse_result.data
		),
		eof_parse_result.remaining_bytes)
