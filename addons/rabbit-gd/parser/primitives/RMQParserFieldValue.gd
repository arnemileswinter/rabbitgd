class_name RMQParserFieldValue
extends RefCounted

class FieldValueVisitor:
	func visit_boolean(value:bool):
		pass
	func visit_short_short_int(value:int):
		pass
	func visit_short_short_uint(value:int):
		pass
	func visit_short_int(value:int):
		pass
	func visit_short_uint(value:int):
		pass
	func visit_long_int(value:int):
		pass
	func visit_long_uint(value:int):
		pass
	func visit_long_long_uint(value:int):
		pass
	func visit_long_long_int(value:int):
		pass
	func visit_float(value:float):
		pass
	func visit_double(value:float):
		pass
	func visit_decimal(value:int):
		pass
	func visit_short_string(value:String):
		pass
	func visit_long_string(value:PackedByteArray):
		pass
	func visit_field_array(value:RMQFieldArray):
		pass
	func visit_timestamp(value:int):
		pass
	func visit_field_table(value:RMQFieldTable):
		pass
	func visit_no_field():
		pass

static func forward(remaining_bytes_0:PackedByteArray,signal_data, on_error: Callable, visitor : FieldValueVisitor = null) -> RMQParseResult:
	var parse_result_u8 = await RMQParserU8.forward(remaining_bytes_0,signal_data, on_error)
	var field_value_discriminator = String.chr(parse_result_u8.data)
	var remaining_bytes = parse_result_u8.remaining_bytes
	var parse_result = null
	match field_value_discriminator:
		't': # boolean
			parse_result = await RMQParserBool.forward(remaining_bytes, signal_data, on_error)
			if visitor: visitor.visit_boolean(parse_result.data)
		'b': # short short int
			parse_result = await RMQParser8.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_short_short_int(parse_result.data)
		'B': # short short uint
			parse_result = await RMQParserU8.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_short_short_uint(parse_result.data)
		'U': # short int
			parse_result = await RMQParser16.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_short_int(parse_result.data)
		'u': # short uint
			parse_result = await RMQParserU16.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_short_uint(parse_result.data)
		'I': # Long int
			parse_result = await RMQParser32.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_long_int(parse_result.data)
		'i': # long uint
			parse_result = await RMQParserU32.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_long_uint(parse_result.data)
		'L': # long long int
			parse_result = await RMQParser64.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_long_long_int(parse_result.data)
		'l': # long long uint
			parse_result = await RMQParserU64.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_long_long_uint(parse_result.data)
		'f': # float
			parse_result = await RMQParserFloat.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_float(parse_result.data)
		'd': # double
			parse_result = await RMQParserDouble.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_double(parse_result.data)
		'D': # decimal value
			parse_result = await RMQParser32.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_decimal(parse_result.data)
		's': # short string
			parse_result = await RMQParserShortString.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_short_string(parse_result.data)
		'S': # long string
			parse_result = await RMQParserLongString.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_long_string(parse_result.data)
		'A': # field array
			parse_result = await RMQParserFieldArray.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_field_array(parse_result.data)
		'T': # timestamp
			parse_result = await RMQParserU64.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_timestamp(parse_result.data)
		'F': # field table
			parse_result = await RMQParserFieldTable.forward(remaining_bytes,signal_data,on_error)
			if visitor: visitor.visit_field_table(parse_result.data)
		'V': # no field
			parse_result = RMQParseResult.new(null,remaining_bytes)
			if visitor: visitor.visit_no_field()
		_:
			return on_error.call("unknown field value discriminator " + field_value_discriminator)
	return parse_result
