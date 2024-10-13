# Very basic example on how to use the rabbitmq client
extends Node2D

var _rmq_client : RMQClient
var _channel : RMQChannel

func _ready() -> void:
	_rmq_client = RMQClient.new()
	# asynchronously opens the connection. Make sure that _rmq_client.tick() is invoked regularly.
	var client_open_error := await _rmq_client.open(
			"localhost",
			5672,
			"guest",
			"guest")
	if client_open_error != OK:
		print_debug(client_open_error)
		return

	# most amqp interactions are conducted through channels, which multiplex a connection
	_channel = await _rmq_client.channel()
	var queue_declare := await _channel.queue_declare("my_queue")
	if queue_declare[0] != OK:
		print_debug(queue_declare)
		return

	# set up a consumer with a function callback
	var consume = await _channel.basic_consume("my_queue", 
		func(channel:RMQChannel,
			 method:RMQBasicClass.Deliver,
			 properties:RMQBasicClass.Properties,
			 body:PackedByteArray):
			print("got message ",body.get_string_from_utf8())
			channel.basic_ack(method.delivery_tag),
		)
	if consume[0] != OK:
		print_debug(queue_declare)
		return

# here we invoke `tick` at every frame.
func _process(_delta: float) -> void:
	_rmq_client.tick()

	# channel may not be initialized if _rmq_client.open has not yet finished being awaited.
	if _channel: 
		var publishing_error := await _channel.basic_publish("", "my_queue", "foo".to_utf8_buffer())
		if publishing_error != OK:
			print_debug(publishing_error)
			return
	
# this serves as a kind of destructor, letting the broker know that we want to shut down gracefully
func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		_rmq_client.close()

# Leaving this here commented, illustrating how TLS connections can be established
# # using a self signed certificate
# var cert = X509Certificate.new()
# var crt_load_err := cert.load("../test_tls/server_certificate.pem") # 
# if crt_load_err != OK:
# 	print("error loading crt ", crt_load_err)
# 	return
# var client_open_error := await _rmq_client.open_tls(
# 		"localhost",
# 		5671,
# 		"guest",
# 		"guest",
# 		"localhost",
# 		TLSOptions.client_unsafe(cert))
