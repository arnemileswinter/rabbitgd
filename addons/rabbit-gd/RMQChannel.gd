class_name RMQChannel
extends RefCounted

# using this error code to indicate a `nack` of a publisher confirm
# because its not used within engine internals
const ERR_UNCONFIRMED = ERR_PRINTER_ON_FIRE 

var _consumers: Dictionary
var _on_return_callbacks : Array[Callable] = []

var _send : Callable
var _channel_number : int
var _frame_max: int
var _tick_signal
var _is_closed = false
var _requested_close = false
var _publisher_confirms = false
var _pending_confirms : Array[ConfirmEmitter] = []
var _sequence : int = 0

signal _frame_received(frame:RMQFrame)
signal _on_content_header(header:RMQContentHeader)
signal _on_content_body(payload:PackedByteArray)

signal _channel_open_ok

signal _exchange_declare_ok
signal _exchange_delete_ok
signal _exchange_bind_ok
signal _exchange_unbind_ok

signal _queue_declare_ok(method:RMQQueueClass.DeclareOk)
signal _queue_bind_ok
signal _queue_unbind_ok
signal _queue_purge_ok
signal _queue_delete_ok

signal _basic_consume_ok(method:RMQBasicClass.ConsumeOk)
signal _basic_cancel_ok(method:RMQBasicClass.CancelOk)
signal _basic_recover_ok
signal _basic_get_response(response)
signal _basic_qos_ok
signal _basic_ack(ack:RMQBasicClass.Ack)
signal _basic_nack(nack:RMQBasicClass.Nack)
signal _basic_ack_or_nack(ack_or_nack)

signal _tx_select_ok
signal _tx_commit_ok
signal _tx_rollback_ok

signal _confirm_select_ok

signal closed


func _init(send, tick_signal, channel_number: int, frame_max: int):
	_send = send
	_tick_signal = tick_signal
	_channel_number = channel_number
	_frame_max = frame_max

func _wait_open():
	await _channel_open_ok

func get_channel_number() -> int:
	return _channel_number

# internal function that does all the inbound data frame parsing and emits respective signals
func _receive_frame(frame: RMQFrame) -> void:
	if frame.frame_type == frame.FrameType.HEADER:
		var header = await RMQContentHeader.from_frame(frame)
		if header:
			_on_content_header.emit(header)
			return
	
	if frame.frame_type == frame.FrameType.BODY:
		_on_content_body.emit(frame.payload)
		return
	
	var deliver = await RMQBasicClass.Deliver.from_frame(frame)
	if deliver:
		_on_deliver(deliver)
		return
	
	var channel_open_ok = await RMQChannelClass.OpenOk.from_frame(frame)
	if channel_open_ok:
		_channel_open_ok.emit(channel_open_ok)
		return

	var channel_close = await RMQChannelClass.Close.from_frame(frame)
	if channel_close:
		_channel_close_ok()
		return

	var channel_close_ok = await RMQChannelClass.CloseOk.from_frame(frame)
	if channel_close_ok:
		if not _requested_close:
			print("[rabbitmq] got close-ok but did not request it. Closing anyway.")
		_set_closed()
		return
	
	var channel_flow = await RMQChannelClass.Flow.from_frame(frame)
	if channel_flow:
		print("[rabbitmq] received channel flow method")
		return

	var channel_flow_ok = await RMQChannelClass.FlowOk.from_frame(frame)
	if channel_flow_ok:
		print("[rabbitmq] received channel flow-ok method")
		return
	
	var exchange_declare_ok = await RMQExchangeClass.DeclareOk.from_frame(frame)
	if exchange_declare_ok:
		_exchange_declare_ok.emit()
		return
	
	var exchange_delete_ok = await RMQExchangeClass.DeleteOk.from_frame(frame)
	if exchange_delete_ok:
		_exchange_delete_ok.emit()
		return
	
	var exchange_bind_ok = await RMQExchangeClass.BindOk.from_frame(frame)
	if exchange_bind_ok:
		_exchange_bind_ok.emit()
		return
	
	var exchange_unbind_ok = await RMQExchangeClass.UnbindOk.from_frame(frame)
	if exchange_unbind_ok:
		_exchange_unbind_ok.emit()
		return
	
	var queue_declare_ok = await RMQQueueClass.DeclareOk.from_frame(frame)
	if queue_declare_ok:
		_queue_declare_ok.emit(queue_declare_ok)
		return
	
	var queue_bind_ok = await RMQQueueClass.BindOk.from_frame(frame)
	if queue_bind_ok:
		_queue_bind_ok.emit()
		return
	
	var queue_unbind_ok = await RMQQueueClass.UnbindOk.from_frame(frame)
	if queue_unbind_ok:
		_queue_unbind_ok.emit()
		return
	
	var queue_purge_ok = await RMQQueueClass.PurgeOk.from_frame(frame)
	if queue_purge_ok:
		_queue_purge_ok.emit()
		return
	
	var queue_delete_ok = await RMQQueueClass.DeleteOk.from_frame(frame)
	if queue_delete_ok:
		_queue_delete_ok.emit()
		return
	
	var basic_consume_ok = await RMQBasicClass.ConsumeOk.from_frame(frame)
	if basic_consume_ok:
		_basic_consume_ok.emit(basic_consume_ok)
		return
	
	var basic_cancel_ok = await RMQBasicClass.CancelOk.from_frame(frame)
	if basic_cancel_ok:
		_basic_cancel_ok.emit(basic_cancel_ok)
		return
	
	var on_return = await RMQBasicClass.Return.from_frame(frame)
	if on_return:
		_on_return(on_return)
		return
	
	var get_empty = await RMQBasicClass.GetEmpty.from_frame(frame)
	if get_empty:
		_basic_get_response.emit(get_empty)
		return
	var get_ok = await RMQBasicClass.GetOk.from_frame(frame)
	if get_ok:
		_basic_get_response.emit(get_ok)
		return
	
	var recover_ok = await RMQBasicClass.RecoverOk.from_frame(frame)
	if recover_ok:
		_basic_recover_ok.emit()
		return
	
	var basic_ack = await RMQBasicClass.Ack.from_frame(frame)
	if basic_ack:
		_on_ack_or_nack(basic_ack)
		return

	var basic_nack = await RMQBasicClass.Nack.from_frame(frame)
	if basic_nack:
		_on_ack_or_nack(basic_nack)
		return
	
	
	var qos_ok = await RMQBasicClass.QosOk.from_frame(frame)
	if qos_ok:
		_basic_qos_ok.emit()
		return
	
	var select_ok = await RMQTxClass.SelectOk.from_frame(frame)
	if select_ok:
		_tx_select_ok.emit()
		return
	
	var commit_ok = await RMQTxClass.CommitOk.from_frame(frame)
	if commit_ok:
		_tx_commit_ok.emit()
		return
	
	var rollback_ok = await RMQTxClass.RollbackOk.from_frame(frame)
	if rollback_ok:
		_tx_rollback_ok.emit()
		return
	
	var confirm_select_ok = await RMQConfirmClass.SelectOk.from_frame(frame)
	if confirm_select_ok:
		_confirm_select_ok.emit()
		return

	print("[rabbitmq] got unexpected frame!")

# internal function for clearing publisher confirms callbacks
func _filter_pending_confirms_by_notify(pending_confirm:ConfirmEmitter, ack_or_nack):
	if pending_confirm.notify_ack_or_nack(ack_or_nack):
		return false
	return true
# internal function for clearing publisher confirms callbacks
func _on_ack_or_nack(ack_or_nack):
	_pending_confirms = _pending_confirms.filter(_filter_pending_confirms_by_notify.bind(ack_or_nack))	

# internal function gathering message deliveries and invoking consumer callbacks
func _on_deliver(deliver : RMQBasicClass.Deliver):
	var consumer = _consumers.get(deliver.consumer_tag)
	if consumer:
		var header : RMQContentHeader = await _on_content_header
		var body = PackedByteArray()
		while body.size() < header.content_body_size:
			var payload = await _on_content_body
			body.append_array(payload)
		await consumer.call(self, deliver, header.properties, body)

# internal function invoking return callbacks on failed message deliveries with mandatory flag
func _on_return(return_method:RMQBasicClass.Return):
	var header : RMQContentHeader = await _on_content_header
	var body = PackedByteArray()
	while body.size() < header.content_body_size:
		var payload = await _on_content_body
		body.append_array(payload)
	for cb in _on_return_callbacks:
		await cb.call(self,return_method,header.properties,body)

# Declares an exchange on the RabbitMQ server.
# 
# @param name The name of the exchange.
# @param type The type of exchange (e.g., 'direct', 'fanout', 'topic', etc.).
# @param passive If true, checks if the exchange exists without modifying it.
# @param durable If true, the exchange will survive a server restart.
# @param auto_delete If true, the exchange will be automatically deleted when no longer in use.
# @param internal If true, the exchange will be internal (not available for client use).
# @param no_wait If true, the server will not respond to the method, saving time.
# @param arguments Additional optional arguments (e.g., for exchange features).
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func exchange_declare(name:String, type:String='direct', passive:bool=false, durable:bool=false,auto_delete:bool=false,internal:bool=false, no_wait:bool=true, arguments:RMQFieldTable=RMQFieldTable.new()) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var exchange_declare_error = await _send.call(RMQExchangeClass.Declare.new(name,type,passive,durable,auto_delete,internal,no_wait,arguments).to_frame(_channel_number).to_wire())
	if exchange_declare_error != OK:
		print("[rabbitmq] error while declaring exchange")
		return exchange_declare_error
	if not no_wait:
		await _exchange_declare_ok
	return OK

# Deletes an exchange from the RabbitMQ server.
# 
# @param name The name of the exchange to delete.
# @param if_unused If true, the exchange will only be deleted if it is not in use by any queues.
# @param no_wait If true, the server will not respond to the method, saving time.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func exchange_delete(name:String,if_unused:bool=false,no_wait:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var exchange_delete_error = await _send.call(RMQExchangeClass.Delete.new(name,if_unused,no_wait).to_frame(_channel_number).to_wire())
	if exchange_delete_error != OK:
		print("[rabbitmq] error while deleting exchange")
		return exchange_delete_error
	if not no_wait:
		await _exchange_delete_ok
	return OK

# Binds an exchange to another exchange (extension by RabbitMQ to the AMQP protocol).
# 
# @note This functionality is specific to RabbitMQ and may not be supported by all brokers.
# 
# @param destination The name of the destination exchange.
# @param source The name of the source exchange.
# @param routing_key The routing key to use for binding.
# @param no_wait If true, the server will not respond to the method, saving time.
# @param arguments Additional optional arguments for the binding.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func exchange_bind(destination:String="",source:String="",routing_key:String="",no_wait:bool=true,arguments:RMQFieldTable=RMQFieldTable.new()):
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var exchange_bind_error = await _send.call(RMQExchangeClass.Bind.new(destination,source,routing_key,no_wait,arguments).to_frame(_channel_number).to_wire())
	if exchange_bind_error != OK:
		print("[rabbitmq] error while binding exchange")
		return exchange_bind_error
	if not no_wait:
		var bound = await _exchange_bind_ok
	return OK

# Unbinds an exchange from another exchange (extension by RabbitMQ to the AMQP protocol).
# 
# @note This functionality is specific to RabbitMQ and may not be supported by all brokers.
# 
# @param destination The name of the destination exchange.
# @param source The name of the source exchange.
# @param routing_key The routing key used for unbinding.
# @param no_wait If true, the server will not respond to the method, saving time.
# @param arguments Additional optional arguments for the unbinding.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func exchange_unbind(destination:String="",source:String="",routing_key:String="",no_wait:bool=true,arguments:RMQFieldTable=RMQFieldTable.new()):
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var exchange_unbind_error = await _send.call(RMQExchangeClass.Unbind.new(destination,source,routing_key,no_wait,arguments).to_frame(_channel_number).to_wire())
	if exchange_unbind_error != OK:
		print("[rabbitmq] error while unbinding exchange")
		return exchange_unbind_error
	if not no_wait:
		var bound = await _exchange_unbind_ok
	return OK

# Declares a queue on the RabbitMQ server.
# 
# @param name The name of the queue. If empty, the broker generates a name.
#             Note: If generating a name, the no_wait flag should not be set if you need to await the generated name.
# @param passive If true, checks if the queue exists without modifying it.
# @param durable If true, the queue will survive a server restart.
# @param exclusive If true, the queue is used exclusively by the connection that declares it.
# @param no_wait If true, the server will not respond to the method, saving time.
# @param arguments Additional optional arguments (e.g., for queue features).
# 
# @return Returns an array where the first element is an error code (OK if successful, FAILED if the channel is closed or an error occurs),
#         and the second element is the declared queue name or null if there was an error.
func queue_declare(name:String="",passive:bool=false,durable:bool=false,exclusive:bool=false,no_wait:bool=name!="",arguments:RMQFieldTable=RMQFieldTable.new()) -> Array:
	if _is_closed:
		push_error("channel is closed")
		return [FAILED,null]
	var exchange_declare_error = await _send.call(RMQQueueClass.Declare.new(name,passive,durable,exclusive,no_wait,arguments).to_frame(_channel_number).to_wire())
	if exchange_declare_error != OK:
		print("[rabbitmq] error while declaring exchange")
		return [exchange_declare_error,null]
	if not no_wait:
		var declared : RMQQueueClass.DeclareOk = await _queue_declare_ok
		return [OK, declared.queue]
	return [OK, name]

# Binds a queue to an exchange.
# 
# @param queue The name of the queue to bind.
# @param exchange The name of the exchange to bind the queue to.
# @param routing_key The routing key used for binding.
# @param no_wait If true, the server will not respond to the method, saving time.
# @param arguments Additional optional arguments for the binding.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func queue_bind(queue:String,exchange:String,routing_key:String="",no_wait:bool=true,arguments:RMQFieldTable=RMQFieldTable.new()) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var queue_bind_error = await _send.call(RMQQueueClass.Bind.new(queue,exchange,routing_key,no_wait,arguments).to_frame(_channel_number).to_wire())
	if  queue_bind_error != OK:
		print("[rabbitmq] error while binding queue")
		return queue_bind_error
	if not no_wait:
		var bound = await _queue_bind_ok
	return OK

# Unbinds a queue from an exchange.
# 
# @param queue The name of the queue to unbind.
# @param exchange The name of the exchange to unbind the queue from.
# @param routing_key The routing key used for unbinding.
# @param arguments Additional optional arguments for the unbinding.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func queue_unbind(queue:String,exchange:String="",routing_key:String="",arguments:RMQFieldTable=RMQFieldTable.new()) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var queue_unbind_error = await _send.call(RMQQueueClass.Unbind.new(queue,exchange,routing_key,arguments).to_frame(_channel_number).to_wire())
	if  queue_unbind_error != OK:
		print("[rabbitmq] error while binding queue")
		return queue_unbind_error
	var bound = await _queue_unbind_ok
	return OK

# Purges all messages from a queue.
# 
# @param queue The name of the queue to purge.
# @param no_wait If true, the server will not respond to the method, saving time.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func queue_purge(queue:String,no_wait:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var queue_purge_error = await _send.call(RMQQueueClass.Purge.new(queue,no_wait).to_frame(_channel_number).to_wire())
	if  queue_purge_error != OK:
		print("[rabbitmq] error while purging queue")
		return queue_purge_error
	if not no_wait:
		var purged = await _queue_purge_ok
	return OK

# Deletes a queue from RabbitMQ.
# 
# @param queue The name of the queue to delete.
# @param if_unused If true, the queue will only be deleted if it is not currently in use.
# @param if_empty If true, the queue will only be deleted if it is empty.
# @param no_wait If true, the server will not respond to the method, saving time.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func queue_delete(queue:String,if_unused:bool=false,if_empty:bool=false,no_wait:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var queue_delete_error = await _send.call(RMQQueueClass.Delete.new(queue,if_unused,if_empty,no_wait).to_frame(_channel_number).to_wire())
	if queue_delete_error != OK:
		print("[rabbitmq] error while deleting queue")
		return queue_delete_error
	if not no_wait:
		var deleted = await _queue_delete_ok
	return OK

# Starts consuming messages from a specified queue.
# 
# @param queue The name of the queue to consume messages from.
# @param on_message A callable that is invoked when a message is received.
# 					Callable must accept parameters (channel:RMQChannel,method:RMQBasicClass.Deliver, properties:RMQBasicClass.Properties, body:PackedByteArray).
# @param consumer_tag An optional identifier for the consumer; if this field is empty, the server will generate a unique tag.
# @param no_local If true, the consumer does not receive messages published on the same connection.
# @param no_ack If true, the server does not expect acknowledgments for received messages.
# @param exclusive If true, the consumer can only be used by this connection.
# @param arguments Additional optional arguments for the consumer.
# @param no_wait If true, the server will not respond to the method, saving time.
# 
# @return Returns an array where the first element is an error code (OK if successful, FAILED if the channel is closed or an error occurs),
#         and the second element is the consumer tag (either the provided tag or the generated one).
func basic_consume(
	queue:String,
	on_message:Callable,
	consumer_tag:String="",
	no_local:bool=false,
	no_ack:bool=false,
	exclusive:bool=false,
	arguments:RMQFieldTable=RMQFieldTable.new(),
	no_wait:bool=consumer_tag!=""
	) -> Array:
	if _is_closed:
		push_error("channel is closed")
		return [FAILED, ""]
	var basic_consume_error = await _send.call(RMQBasicClass.Consume.new(
		queue,
		consumer_tag,
		no_local,
		no_ack,
		exclusive,
		no_wait,
		arguments
	).to_frame(_channel_number).to_wire())
	if basic_consume_error != OK:
		print("[rabbitmq] error while consume queue")
		return [basic_consume_error, ""]
	
	if not no_wait:
		var consuming = await _basic_consume_ok
		consumer_tag = consuming.consumer_tag	
	_consumers[consumer_tag] = on_message
	return [OK,consumer_tag]

# Acknowledges the receipt of one or more messages.
# 
# @param delivery_tag The identifier of the message to acknowledge.
# @param multiple If true, acknowledges all messages up to and including the message identified by delivery_tag.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_ack(delivery_tag:int=0,multiple:bool=false) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_ack_error = await _send.call(RMQBasicClass.Ack.new(delivery_tag,multiple).to_frame(_channel_number).to_wire())
	if basic_ack_error != OK:
		print("[rabbitmq] error while ack")
	return OK

# Rejects the receipt of a message.
# 
# @param delivery_tag The identifier of the message to reject.
# @param requeue If true, the rejected message will be requeued for redelivery; otherwise, it will be discarded.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_reject(delivery_tag:int=0,requeue:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_reject_error = await _send.call(RMQBasicClass.Reject.new(delivery_tag,requeue).to_frame(_channel_number).to_wire())
	if basic_reject_error != OK:
		print("[rabbitmq] error while reject")
	return basic_reject_error

# Negatively acknowledges the receipt of one or more messages.
# 
# @param delivery_tag The identifier of the message to negatively acknowledge.
# @param multiple If true, negatively acknowledges all messages up to and including the message identified by delivery_tag.
# @param requeue If true, the negatively acknowledged message will be requeued for redelivery; otherwise, it will be discarded.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_nack(delivery_tag:int=0,multiple:bool=false,requeue:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_nack_error = await _send.call(RMQBasicClass.Nack.new(delivery_tag,multiple,requeue).to_frame(_channel_number).to_wire())
	if basic_nack_error != OK:
		print("[rabbitmq] error while nack")
	return basic_nack_error

# Asynchronously recovers unacknowledged messages.
# 
# @note This method is deprecated as per the AMQP specification.
# 
# @param requeue If true, unacknowledged messages will be requeued for redelivery; otherwise, they will be discarded.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_recover_async(requeue:bool=false) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_recover_error = await _send.call(RMQBasicClass.RecoverAsync.new(requeue).to_frame(_channel_number).to_wire())
	if basic_recover_error != OK:
		print("[rabbitmq] error while recover async")
	return basic_recover_error	

# Recovers unacknowledged messages.
# 
# @param requeue If true, unacknowledged messages will be requeued for redelivery; otherwise, they will be discarded.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_recover(requeue:bool=false) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_recover_error = await _send.call(RMQBasicClass.Recover.new(requeue).to_frame(_channel_number).to_wire())
	if basic_recover_error != OK:
		print("[rabbitmq] error while recover")
		return basic_recover_error
	await _basic_recover_ok
	return OK
	
# Retrieves a message from a specified queue.
# 
# @note This method allows for synchronous access to messages in a queue, which is suitable for applications
#       that prioritize synchronous operations over performance.
# 
# @param queue The name of the queue to get a message from.
# @param no_ack If true, the server will not expect an acknowledgment for the retrieved message.
# 
# @return Returns an array where the first element is an error code (OK if successful, FAILED if the channel is closed or an error occurs),
#         the second element is the method response (either GetOk or GetEmpty), the third element is the content header,
#         and the fourth element is the message body. If there is no message, the second element will be null.
func basic_get(queue:String,no_ack:bool=false) -> Array:
	if _is_closed:
		push_error("channel is closed")
		return [FAILED,null,null,null]
	var basic_get_error = await _send.call(RMQBasicClass.Get.new(queue,no_ack).to_frame(_channel_number).to_wire())
	if basic_get_error != OK:
		print("[rabbitmq] error while get queue")
		return [basic_get_error]
	var method = _basic_get_response
	if method is RMQBasicClass.GetEmpty:
		return [OK,null,null,null]
	elif method is RMQBasicClass.GetOk:
		var header : RMQContentHeader = await _on_content_header
		var body = PackedByteArray()
		while body.size() < header.content_body_size:
			var payload = await _on_content_body
			body.append_array(payload)
		return [OK,method,header,body]
	else:
		push_error("[rabbitmq] unreachable!")
		return [ERR_BUG,null,null,null]

# Cancels a consumer subscription.
# 
# @param consumer_tag The identifier of the consumer to cancel. If empty, the last declared consumer is cancelled.
# @param no_wait If true, the server will not respond to the cancellation request, saving time.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
func basic_cancel(consumer_tag:String,no_wait:bool=true) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_cancel_error = await _send.call(RMQBasicClass.Cancel.new(
		consumer_tag,
		no_wait
	).to_frame(_channel_number).to_wire())
	if basic_cancel_error != OK:
		print("[rabbitmq] error while cancelling")
		return basic_cancel_error
	
	if not no_wait:
		var consumer_cancelled = await _basic_cancel_ok
		if consumer_cancelled.consumer_tag != consumer_tag:
			print("[rabbitmq] got consumer.cancel-ok for mismatched tag, expected: ", consumer_tag, ", got: ", consumer_cancelled.consumer_tag)
			return ERR_INVALID_DATA
	_consumers.erase(consumer_tag)
	return OK

# Publishes a message to a specified exchange.
# If publisher confirms are enabled, this coroutine will return only after the broker acknowledged the message (or nack).
# 
# @param exchange The name of the exchange to publish the message to.
# @param routing_key The routing key used to route the message to the appropriate queue.
# @param body The message body as a PackedByteArray.
# @param mandatory If true, the server will return the message if it cannot route it to any queue.
# @param properties Optional message properties (e.g., headers, content type).
# @param immediate If true, the server will return the message if it cannot deliver it immediately.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs,
#         ERR_UNCONFIRMED if publisher_confirms are enabled and a `nack` was received).
func basic_publish(exchange:String,routing_key:String,body:PackedByteArray,mandatory:bool=false,properties:RMQBasicClass.Properties=RMQBasicClass.Properties.new(),immediate:bool=false) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	_sequence += 1
	var expected_delivery_tag :int = _sequence
	var basic_publish_error = await _send.call(RMQBasicClass.Publish.new(
		exchange,
		routing_key,
		mandatory,
		immediate
	).to_frame(_channel_number).to_wire())
	if basic_publish_error != OK:
		print("[rabbitmq] error while publishing: ", basic_publish_error)
		return basic_publish_error
	
	var content_header_error = await _send.call(RMQContentHeader.new(RMQBasicClass.CLASS_ID, 0, body.size(), properties).to_frame(_channel_number).to_wire())
	if content_header_error != OK:
		print("[rabbitmq] error while sending content header")
		return content_header_error
	
	if body.size() > _frame_max:
		var chunk = body.slice(0, _frame_max)
		body = body.slice(_frame_max)
		var content_body_error = await _send.call(RMQFrame.new(RMQFrame.FrameType.BODY, _channel_number, chunk).to_wire())
		if content_body_error != OK:
			print("[rabbitmq] error while sending content body")
			return content_body_error
		# chunking into many frames
		while body.size() > 0:
			await _tick_signal
			chunk = body.slice(0, _frame_max)
			body = body.slice(_frame_max)
			content_body_error = await _send.call(RMQFrame.new(RMQFrame.FrameType.BODY, _channel_number, chunk).to_wire())
			if content_body_error != OK:
				print("[rabbitmq] error while sending content body")
				return content_body_error
	else:
		# body is small enough to fit into one frame
		var content_body_error = await _send.call(RMQFrame.new(RMQFrame.FrameType.BODY, _channel_number, body).to_wire())
		if content_body_error != OK:
			print("[rabbitmq] error while sending content body")
			return content_body_error

	if _publisher_confirms:
		var confirm_emitter = ConfirmEmitter.new(expected_delivery_tag)
		_pending_confirms.append(confirm_emitter)
		var confirmed: bool = await confirm_emitter.confirmed
		if not confirmed:
			return ERR_UNCONFIRMED
	return OK

# Sets Quality of Service (QoS) settings for message consumption.
# 
# @param prefetch_size The maximum number of bytes the server will send over the channel before waiting for acknowledgments.
#                     A value of 0 means no limit on the number of bytes.
# @param prefetch_count The maximum number of messages the server will send over the channel before waiting for acknowledgments.
#                      A value of 0 means no limit on the number of unacknowledged messages.
# @param global If true, the QoS settings apply to the entire connection; otherwise, they apply to the current channel only.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
#         This method also waits for a confirmation that the QoS settings have been applied before returning.
func basic_qos(prefetch_size:int=0,prefetch_count:int=0,global:bool=false) -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var basic_qos_error = await _send.call(RMQBasicClass.Qos.new(prefetch_size,prefetch_count,global).to_frame(_channel_number).to_wire())
	if basic_qos_error != OK:
		print("[rabbitmq] error while qos: ", basic_qos_error)
		return basic_qos_error
	await _basic_qos_ok
	return OK

# Selects the transactional mode for the channel.
# 
# This method enables transaction support on the current channel, allowing the publisher to send messages in a transactional manner.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
#         This method also waits for a confirmation that the transaction mode has been enabled before returning.
func tx_select() -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var tx_select_error = await _send.call(RMQTxClass.Select.new().to_frame(_channel_number).to_wire())
	if tx_select_error != OK:
		print("[rabbitmq] error while select", tx_select_error)
		return tx_select_error
	await _tx_select_ok
	return OK

# Commits the current transaction on the channel.
# 
# This method finalizes the transaction, making all messages sent in the transaction visible to consumers.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
#         This method also waits for a confirmation that the transaction has been committed before returning.
func tx_commit() -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var tx_commit_error = await _send.call(RMQTxClass.Commit.new().to_frame(_channel_number).to_wire())
	if tx_commit_error != OK:
		print("[rabbitmq] error while commit", tx_commit_error)
		return tx_commit_error
	await _tx_commit_ok
	return OK

# Rolls back the current transaction on the channel.
# 
# This method reverts any messages sent in the current transaction, making them invisible to consumers.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed or an error occurs).
#         This method also waits for a confirmation that the transaction has been rolled back before returning.
func tx_rollback() -> Error:
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var tx_rollback_error = await _send.call(RMQTxClass.Rollback.new().to_frame(_channel_number).to_wire())
	if tx_rollback_error != OK:
		print("[rabbitmq] error while rollback", tx_rollback_error)
		return tx_rollback_error
	await _tx_rollback_ok
	return OK

# Adds a callback function that is invoked when a message cannot be delivered.
# 
# This callback is triggered when a message published with the `mandatory` flag set to true cannot be routed to any queue.
# 
# @param on_return A callable that will be invoked with the details of the undelivered message.
#                  The callable is expected to receive the following arguments: (channel:RMQChannel,return_method:RMQBasicClass.Return,properties: RMQBasicClass.Properties,body:PackedByteArray)
func add_on_return_callback(on_return:Callable):
	_on_return_callbacks.append(on_return)

# Enables publisher confirms for the current channel.
#
# When enabled, the server acknowledges messages published to the channel,
# allowing the publisher to know whether the message was successfully processed.
#
# @param no_wait If true, the server will not send a response for this method, 
#                allowing for faster processing but without confirmation that the 
#                request was received.
# 
# @return Returns an error code (OK if successful, FAILED if the channel is closed 
#         or an error occurs).
func confirm_select(no_wait:bool=true):
	if _is_closed:
		push_error("channel is closed")
		return FAILED
	var confirm_select_error = await _send.call(RMQConfirmClass.Select.new(
		no_wait
	).to_frame(_channel_number).to_wire())
	if confirm_select_error != OK:
		print("[rabbitmq] error while confirm.select")
		return confirm_select_error
	
	if not no_wait:
		await _confirm_select_ok
	_publisher_confirms = true
	return OK

# Closes the current channel and releases associated resources.
#
# @param reply_code A numeric reply code indicating the reason for closing the channel.
# @param reply_text A human-readable text explaining the reason for the closure.
# @param class_id The class ID of the method that caused the closure.
# @param method_id The method ID of the method that caused the closure.
#
# @return Returns an error code (OK if successful, or an error code if the 
#         close operation fails).
func close(reply_code=200, reply_text="",class_id=0,method_id=0) -> Error:
	var channel_close_error = await _send.call(RMQChannelClass.Close.new(reply_code,reply_text,class_id,method_id).to_frame(_channel_number).to_wire())
	if channel_close_error != OK:
		print("[rabbitmq] error while close in channel")
	_requested_close = true
	return channel_close_error

# internal function when upstream closes our channel.
func _channel_close_ok()->void:
	var channel_close_error = await _send.call(RMQChannelClass.CloseOk.new().to_frame(_channel_number).to_wire())
	if channel_close_error != OK:
		print("[rabbitmq] error while close-ok in channel")
	_set_closed()

# internal function to mark the channel as closed and emit the closed event.
func _set_closed():
	_is_closed = true
	closed.emit()

# check if the channel has been closed
func is_closed():
	return _is_closed

# internal class to conditionally emit the confirmed signal such that basic.publish can await it
class ConfirmEmitter:
	signal confirmed(ok:bool)
	var _delivery_tag : int 
	
	func _init(delivery_tag: int):
		self._delivery_tag = delivery_tag
	
	func notify_ack_or_nack(ack_or_nack):
		if ack_or_nack is RMQBasicClass.Ack:
			var ack : RMQBasicClass.Ack = ack_or_nack
			if ack.multiple:
				if self._delivery_tag <= ack.delivery_tag:
					confirmed.emit(true)
					return true
			if ack.delivery_tag == self._delivery_tag:
				confirmed.emit(true)
				return true
		if ack_or_nack is RMQBasicClass.Nack:
			var nack : RMQBasicClass.Nack = ack_or_nack
			if nack.multiple:
				if self._delivery_tag <= nack.delivery_tag:
					confirmed.emit(false)
					return true
			if nack.delivery_tag == self._delivery_tag:
				confirmed.emit(false)
				return true
		return false
