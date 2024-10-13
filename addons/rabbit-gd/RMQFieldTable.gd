class_name RMQFieldTable
extends RefCounted

# Backing byte buffer to send table values over wire.
# Assumed read-only for clients.
# Do not modify.
var buffer : StreamPeerBuffer = StreamPeerBuffer.new()
# Backing godot variable to access values.
# Assumed read-only for clients.
# Do not modify.
var variant : Dictionary = {}

func _init():
	buffer.big_endian = true

func _key(key: String):
	RMQEncodePrimitives.put_short_string(buffer, key)

func put_boolean(key: String, value:bool):
	_key(key)
	RMQEncodePrimitives._put_field_boolean(buffer,value)
	variant[key] = value

func put_short_short_int(key: String, value:int):
	_key(key)
	RMQEncodePrimitives._put_field_short_short_int(buffer,value)
	variant[key] = value

func put_short_short_uint(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_short_short_uint(buffer,value)
	variant[key] = value

func put_short_int(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_short_int(buffer,value)
	variant[key] = value

func put_short_uint(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_short_uint(buffer,value)
	variant[key] = value

func put_long_int(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_long_int(buffer,value)
	variant[key] = value

func put_long_uint(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_long_uint(buffer,value)
	variant[key] = value

func put_long_long_int(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_long_long_int(buffer,value)
	variant[key] = value

func put_long_long_uint(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_long_long_uint(buffer,value)
	variant[key] = value

func put_float(key: String,value:float):
	_key(key)
	RMQEncodePrimitives._put_field_float(buffer,value)
	variant[key] = value

func put_double(key: String,value:float):
	_key(key)
	RMQEncodePrimitives._put_field_double(buffer,value)
	variant[key] = value

func put_decimal_value(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_decimal(buffer,value)
	variant[key] = value

func put_short_string(key: String,value:String):
	_key(key)
	RMQEncodePrimitives._put_field_short_string(buffer,value)
	variant[key] = value

func put_long_string(key: String,value:PackedByteArray):
	_key(key)
	RMQEncodePrimitives._put_field_long_string(buffer,value)
	variant[key] = value

func put_timestamp(key: String,value:int):
	_key(key)
	RMQEncodePrimitives._put_field_timestamp(buffer,value)
	variant[key] = value

func put_table(key: String,value:RMQFieldTable):
	_key(key)
	RMQEncodePrimitives._put_field_table(buffer,value)
	variant[key] = value

func put_no_field(key: String):
	_key(key)
	RMQEncodePrimitives._put_field_no_field(buffer)
	variant[key] = null
	
func put_array(key: String,value:RMQFieldArray):
	_key(key)
	RMQEncodePrimitives._put_field_array(buffer,value)
	variant[key] = value
