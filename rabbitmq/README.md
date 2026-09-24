# RabbitMQ — topología del caso

`rabbitmq.conf` importa `definitions.json` al arrancar el broker
(`load_definitions`). Ahí se declara la topología del caso
(ver `contratos/rabbitmq.md` en el repo central):

- Exchanges: `cmd.direct` (direct), `cmd.topic` (topic), `cmd.dead.dlx` (topic,
  para enrutar con comodines los mensajes muertos conserven o no su routing key).
- Colas: `q.cmd.email`, `q.cmd.warehouse`, `q.cmd.label` (durables, con DLX
  `cmd.dead.dlx`) y sus DLQ `q.cmd.{email,warehouse,label}.dlq`.
- Bindings direct: `email.send`, `warehouse.ticket`, `label.gen`.
- Bindings topic: `email.*`, `warehouse.#`, `label.*`.
- Bindings del DLX: `email.#`, `warehouse.#`, `label.#`.

## Envelope (productores)

Al publicar en las 3 colas, usar el envelope común:
`type`, `eventId`, `timestamp`, `traceId`, `correlationId`, con ACK/NACK
explícitos e idempotencia en el consumidor.

## Notas

- La cola legacy `rutaexpress.notifications` **no** se declara aquí a propósito:
  si ya existe con otros parámetros, re-declararla rompería el arranque; el flujo
  actual sigue funcionando y los productores migran a las 3 colas.
- Pendiente (follow-up): clúster de 2 nodos + Management UI expuesta según el caso.
- Verificar en Management UI (`http://localhost:15672`): Exchanges, Queues y Bindings.
