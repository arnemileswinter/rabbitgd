class_name RMQParserFieldTable
extends RefCounted

static func forward(remaining_bytes_0:PackedByteArray,signal_data, on_error: Callable) -> RMQParseResult:
	var parse_result_ls = await RMQParserLongString.forward(remaining_bytes_0,signal_data, on_error)
	var table_buffer : PackedByteArray = parse_result_ls.data
	var table : RMQFieldTable = RMQFieldTable.new()
	var parse_visitor = RMQParserFieldTableVisitor.new()
	parse_visitor.table = table
	while not table_buffer.is_empty():
		var parse_result_table_field_name = await RMQParserShortString.forward(table_buffer, null, on_error)
		var table_field_name = parse_result_table_field_name.data
		parse_visitor.next_key = table_field_name
		table_buffer = parse_result_table_field_name.remaining_bytes
		var parse_result_table_field_value = await RMQParserFieldValue.forward(table_buffer, null, on_error, parse_visitor)
		table_buffer = parse_result_table_field_value.remaining_bytes
	return RMQParseResult.new(table, parse_result_ls.remaining_bytes)

class RMQParserFieldTableVisitor extends RMQParserFieldValue.FieldValueVisitor:
	var next_key : String
	var table: RMQFieldTable
	
	func visit_boolean(value:bool):
		table.put_boolean(next_key,value)
	func visit_short_short_int(value:int):
		table.put_short_short_int(next_key,value)
	func visit_short_short_uint(value:int):
		table.put_short_short_uint(next_key,value)
	func visit_short_int(value:int):
		table.put_short_int(next_key,value)
	func visit_short_uint(value:int):
		table.put_short_uint(next_key,value)
	func visit_long_int(value:int):
		table.put_long_int(next_key,value)
	func visit_long_uint(value:int):
		table.put_long_uint(next_key,value)
	func visit_long_long_uint(value:int):
		table.put_long_long_uint(next_key,value)
	func visit_long_long_int(value:int):
		table.put_long_long_int(next_key,value)
	func visit_float(value:float):
		table.put_float(next_key,value)
	func visit_double(value:float):
		table.put_double(next_key,value)
	func visit_decimal(value:int):
		table.put_decimal_value(next_key,value)
	func visit_short_string(value:String):
		table.put_short_string(next_key,value)
	func visit_long_string(value:PackedByteArray):
		table.put_long_string(next_key,value)
	func visit_field_array(value:RMQFieldArray):
		table.put_array(next_key,value)
	func visit_timestamp(value:int):
		table.put_timestamp(next_key,value)
	func visit_field_table(value:RMQFieldTable):
		table.put_table(next_key,value)
	func visit_no_field():
		table.put_no_field(next_key)
