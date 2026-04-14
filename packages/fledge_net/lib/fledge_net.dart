/// Networking components for Fledge.
///
/// This library provides peer-to-peer networking for multiplayer games:
///
/// - **Transport**: UDP socket communication
/// - **Host/Client**: Connection management
/// - **State Sync**: Component replication
/// - **Input Sync**: Prediction and reconciliation
///
/// ## Hosting a Game
///
/// ```dart
/// final transport = UdpTransport();
/// final host = NetworkHost(transport: transport);
///
/// await host.start(7777);
/// print('Room code: ${host.roomCode}');
///
/// host.onPeerConnected.listen((event) {
///   print('Player joined: ${event.peer.id}');
/// });
///
/// // Broadcast state updates
/// host.broadcast(PacketType.stateUpdate, stateData);
/// ```
///
/// ## Joining a Game
///
/// ```dart
/// final transport = UdpTransport();
/// final client = NetworkClient(transport: transport);
///
/// if (await client.connect('192.168.1.100', 7777)) {
///   print('Connected! ID: ${client.localPeerId}');
///
///   client.onData.listen((event) {
///     // Handle state updates
///   });
///
///   // Send inputs
///   client.send(PacketType.input, inputData);
/// }
/// ```
///
/// ## State Synchronization
///
/// Mark entities for network sync:
///
/// ```dart
/// world.spawn()
///   ..insert(NetworkIdentity(netId: registry.generateNetId()))
///   ..insert(Transform3D())
///   ..insert(Player());
/// ```
///
/// ## Input Prediction
///
/// ```dart
/// final prediction = ClientPrediction();
///
/// // Record local input
/// final input = InputFrame(tick: prediction.nextTick());
/// input.moveX = controller.moveX;
/// input.moveY = controller.moveY;
/// prediction.recordInput(input, currentState);
///
/// // When server state arrives, reconcile
/// final inputsToReplay = prediction.reconcile(serverTick, serverState);
/// ```
library;

// Transport
export 'src/transport/transport.dart';
export 'src/transport/udp_transport.dart';

// Protocol
export 'src/protocol/packet.dart';

// Connection
export 'src/connection/client.dart';
export 'src/connection/host.dart';
export 'src/connection/peer.dart';

// Sync
export 'src/sync/input_sync.dart';
export 'src/sync/network_identity.dart';
export 'src/sync/state_sync.dart';

// Plugin
export 'src/plugin.dart';
