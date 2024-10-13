class_name RMQParserFieldArray
extends RefCounted

static func forward(remaining_bytes_0:PackedByteArray,signal_data, on_error: Callable) -> RMQParseResult:
	var parse_result_ls = await RMQParserLongString.forward(remaining_bytes_0,signal_data, on_error)
	var array_buffer : PackedByteArray = parse_result_ls.data
	var array = RMQFieldArray.new()
	var array_parse_visitor = RMQParserFieldArrayVisitor.new()
	array_parse_visitor.array = array
	while not array_buffer.is_empty():
		var parse_result_array_field_value = await RMQParserFieldValue.forward(array_buffer, null, on_error, array_parse_visitor)
		array_buffer = parse_result_array_field_value.remaining_bytes
	return RMQParseResult.new(array, parse_result_ls.remaining_bytes)


class RMQParserFieldArrayVisitor extends RMQParserFieldValue.FieldValueVisitor:
	var array: RMQFieldArray
	
	func visit_boolean(value:bool):
		array.put_boolean(value)
	func visit_short_short_int(value:int):
		array.put_short_short_int(value)
	func visit_short_short_uint(value:int):
		array.put_short_short_uint(value)
	func visit_short_int(value:int):
		array.put_short_int(value)
	func visit_short_uint(value:int):
		array.put_short_uint(value)
	func visit_long_int(value:int):
		array.put_long_int(value)
	func visit_long_uint(value:int):
		array.put_long_uint(value)
	func visit_long_long_uint(value:int):
		array.put_long_long_uint(value)
	func visit_long_long_int(value:int):
		array.put_long_long_int(value)
	func visit_float(value:float):
		array.put_float(value)
	func visit_double(value:float):
		array.put_double(value)
	func visit_decimal(value:int):
		array.put_decimal_value(value)
	func visit_short_string(value:String):
		array.put_short_string(value)
	func visit_long_string(value:PackedByteArray):
		array.put_long_string(value)
	func visit_field_array(value:RMQFieldArray):
		array.put_array(value)
	func visit_timestamp(value:int):
		array.put_timestamp(value)
	func visit_field_table(value:RMQFieldTable):
		array.put_table(value)
	func visit_no_field():
		array.put_no_field()
