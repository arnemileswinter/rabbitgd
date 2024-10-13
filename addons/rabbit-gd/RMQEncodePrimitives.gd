class_name RMQEncodePrimitives
extends RefCounted

static func put_short_string(buffer: StreamPeer, value:String):
	var utf8_value := value.to_utf8_buffer()
	buffer.put_u8(utf8_value.size())
	buffer.put_data(utf8_value)

static func put_long_string(buffer: StreamPeer,bytes:PackedByteArray):
	buffer.put_u32(bytes.size())
	buffer.put_data(bytes)

static func put_table(buffer: StreamPeer,table:RMQFieldTable):
	var data = table.buffer.data_array
	buffer.put_u32(data.size())
	buffer.put_data(data)

static func put_bits(buffer:StreamPeer,flags:Array[bool]):
	var packed_byte: int = 0
	var bit_count: int = 0
	
	for bit in flags:
		if bit:
			packed_byte |= (1 << bit_count)
		bit_count += 1
		
		if bit_count == 8:
			buffer.put_u8(packed_byte)
			packed_byte = 0
			bit_count = 0
	
	if bit_count > 0:  # If there are remaining bits
		buffer.put_u8(packed_byte)
	
static func _put_field_boolean(buffer: StreamPeer, value:bool):
	buffer.put_data('t'.to_utf8_buffer())
	if value:
		buffer.put_u8(1)
	else:
		buffer.put_u8(0)

static func _put_field_short_short_int(buffer: StreamPeer, value:int):
	buffer.put_data('b'.to_utf8_buffer())
	buffer.put_8(value)

static func _put_field_short_short_uint(buffer: StreamPeer,value:int):
	buffer.put_data('B'.to_utf8_buffer())
	buffer.put_u8(value)

static func _put_field_short_int(buffer: StreamPeer,value:int):
	buffer.put_data('U'.to_utf8_buffer())
	buffer.put_16(value)

static func _put_field_short_uint(buffer: StreamPeer,value:int):
	buffer.put_data('u'.to_utf8_buffer())
	buffer.put_u16(value)

static func _put_field_long_int(buffer: StreamPeer,value:int):
	buffer.put_data('I'.to_utf8_buffer())
	buffer.put_32(value)

static func _put_field_long_uint(buffer: StreamPeer,value:int):
	buffer.put_data('i'.to_utf8_buffer())
	buffer.put_u32(value)

static func _put_field_long_long_int(buffer: StreamPeer,value:int):
	buffer.put_data('L'.to_utf8_buffer())
	buffer.put_64(value)

static func _put_field_long_long_uint(buffer: StreamPeer,value:int):
	buffer.put_data('l'.to_utf8_buffer())
	buffer.put_u64(value)

static func _put_field_float(buffer: StreamPeer,value:float):
	buffer.put_data('f'.to_utf8_buffer())
	buffer.put_float(value)

static func _put_field_double(buffer: StreamPeer,value:float):
	buffer.put_data('d'.to_utf8_buffer())
	buffer.put_double(value)

static func _put_field_decimal(buffer: StreamPeer,value:int):
	buffer.put_data('D'.to_utf8_buffer())
	buffer.put_32(value)

static func _put_field_short_string(buffer: StreamPeer,value:String):
	buffer.put_data('s'.to_utf8_buffer())
	var utf8_value = value.to_utf8_buffer()
	buffer.put_u8(utf8_value.size())
	buffer.put_data(utf8_value)

static func _put_field_long_string(buffer: StreamPeer,value:PackedByteArray):
	buffer.put_data('S'.to_utf8_buffer())
	buffer.put_u32(value.size())
	buffer.put_data(value)

static func _put_field_timestamp(buffer: StreamPeer,value:int):
	buffer.put_data('T'.to_utf8_buffer())
	buffer.put_u64(value)

static func _put_field_table(buffer: StreamPeer,value:RMQFieldTable):
	buffer.put_data('F'.to_utf8_buffer())
	var data = value.buffer.data_array
	buffer.put_u32(data.size())
	buffer.put_data(data)

static func _put_field_array(buffer: StreamPeer,value:RMQFieldArray):
	buffer.put_data('A'.to_utf8_buffer())
	var data = value.buffer.data_array
	buffer.put_u32(data.size())
	buffer.put_data(data)

static func _put_field_no_field(buffer: StreamPeer):
	buffer.put_data('V'.to_utf8_buffer())
