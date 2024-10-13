class_name RMQParseResult
extends RefCounted

var data : Variant
var remaining_bytes : PackedByteArray

func _init(data:Variant,remaining_bytes:PackedByteArray):
	self.data=data
	self.remaining_bytes=remaining_bytes
