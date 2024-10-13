class_name RMQFieldArray
extends RefCounted

# Backing byte buffer to send table values over wire.
# Assumed read-only for clients.
# Do not modify
var buffer : StreamPeerBuffer = StreamPeerBuffer.new()
# Backing godot variable to access values.
# Assumed read-only for clients.
# Do not modify.
var variant : Array = []

func _init():
	buffer.big_endian = true

func put_boolean(value:bool):
	RMQEncodePrimitives._put_field_boolean(buffer,value)
	variant.append(value)

func put_short_short_int(value:int):
	RMQEncodePrimitives._put_field_short_short_int(buffer,value)
	variant.append(value)

func put_short_short_uint(value:int):
	RMQEncodePrimitives._put_field_short_short_uint(buffer,value)
	variant.append(value)

func put_short_int(value:int):
	RMQEncodePrimitives._put_field_short_int(buffer,value)
	variant.append(value)

func put_short_uint(value:int):
	RMQEncodePrimitives._put_field_short_uint(buffer,value)
	variant.append(value)

func put_long_int(value:int):
	RMQEncodePrimitives._put_field_long_int(buffer,value)
	variant.append(value)

func put_long_uint(value:int):
	RMQEncodePrimitives._put_field_long_uint(buffer,value)
	variant.append(value)

func put_long_long_int(value:int):
	RMQEncodePrimitives._put_field_long_long_int(buffer,value)
	variant.append(value)

func put_long_long_uint(value:int):
	RMQEncodePrimitives._put_field_long_long_uint(buffer,value)
	variant.append(value)

func put_float(value:float):
	RMQEncodePrimitives._put_field_float(buffer,value)
	variant.append(value)

func put_double(value:float):
	RMQEncodePrimitives._put_field_double(buffer,value)
	variant.append(value)

func put_decimal_value(value:int):
	RMQEncodePrimitives._put_field_decimal(buffer,value)
	variant.append(value)

func put_short_string(value:String):
	RMQEncodePrimitives._put_field_short_string(buffer,value)
	variant.append(value)
	
func put_long_string(value:PackedByteArray):
	RMQEncodePrimitives._put_field_long_string(buffer,value)
	variant.append(value)

func put_timestamp(value:int):
	RMQEncodePrimitives._put_field_timestamp(buffer,value)
	variant.append(value)

func put_table(value:RMQFieldTable):
	RMQEncodePrimitives._put_field_table(buffer,value)
	variant.append(value.variant)

func put_no_field():
	RMQEncodePrimitives._put_field_no_field(buffer)
	variant.append(null)
	
func put_array(value:RMQFieldArray):
	RMQEncodePrimitives._put_field_array(buffer,value)
	variant.append(value.variant)
