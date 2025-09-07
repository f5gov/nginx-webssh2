# PM2 Multi-Process Implementation for nginx-webssh2

## Overview

This document outlines a comprehensive plan to implement PM2 clustering for the nginx-webssh2 project, enabling multi-process Node.js execution to better utilize CPU cores and improve scalability.

## Current Architecture Limitations

### Single-Threaded Nature
- WebSSH2 currently runs as a single Node.js process
- Managed by s6-overlay for process supervision
- Cannot utilize multiple CPU cores effectively
- Single point of failure for all WebSocket connections

### Stateful Challenges
- Each WebSocket connection maintains persistent SSH state
- Sessions stored in memory (express-session MemoryStore)
- Socket.IO requires sticky sessions for proper handshaking
- No sharing of session data between processes

## Research Findings

### PM2 Cluster Mode Capabilities
PM2 provides production-ready process management with:
- **Automatic load balancing** across CPU cores
- **Zero-downtime reloads** for updates
- **Auto-restart** on failure
- **Built-in monitoring** and metrics
- **Memory management** with configurable limits

### Socket.IO Clustering Requirements

#### The Core Challenge
Socket.IO performs multiple HTTP requests during handshaking before establishing a WebSocket connection. In a clustered environment, these requests may reach different workers, breaking the connection establishment.

#### Solution: @socket.io/pm2
The official Socket.IO solution provides:
- **Sticky sessions** - Routes all requests from a client to the same worker
- **Cluster adapter** - Broadcasts packets across all workers
- **Drop-in replacement** for standard PM2

Installation:
```bash
npm install -g @socket.io/pm2
```

Usage in code:
```javascript
const { createAdapter } = require("@socket.io/cluster-adapter");
const { setupWorker } = require("@socket.io/sticky");

io.adapter(createAdapter());
setupWorker(io);
```

### Alternative Approaches

#### 1. WebSocket-Only Transport
- Disable HTTP long-polling fallback
- WebSocket uses single TCP connection (no sticky session needed)
- Simpler architecture but no fallback mechanism

#### 2. Redis Adapter
- Use Redis to share state between processes
- Enables true horizontal scaling
- Required for multi-server deployments

#### 3. External Load Balancer
- Use NGINX or HAProxy with IP-hash for sticky sessions
- More complex but provides additional control

## Implementation Plan

### Phase 1: Docker Container Updates

#### 1.1 Dockerfile Modifications
```dockerfile
# Install PM2 globally
RUN npm install -g @socket.io/pm2

# Remove s6-overlay installation
# Use pm2-runtime as the main process
CMD ["pm2-runtime", "start", "ecosystem.config.js"]
```

#### 1.2 Remove s6-overlay Dependencies
- Remove s6-overlay download and installation
- Remove `/etc/s6-overlay/` directory structure
- Replace with PM2 configuration files

### Phase 2: PM2 Configuration

#### 2.1 Create ecosystem.config.js
```javascript
module.exports = {
  apps: [{
    name: 'webssh2',
    script: '/usr/src/webssh2/index.js',
    instances: process.env.PM2_INSTANCES || 'max',
    exec_mode: 'cluster',
    max_memory_restart: '500M',
    
    // Environment variables
    env: {
      NODE_ENV: 'production',
      WEBSSH2_LISTEN_IP: '127.0.0.1',
      WEBSSH2_LISTEN_PORT: 2222,
    },
    
    // PM2 Plus features
    error_file: '/var/log/webssh2/error.log',
    out_file: '/var/log/webssh2/out.log',
    merge_logs: true,
    time: true,
    
    // Graceful shutdown
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 3000,
    
    // Auto-restart configuration
    autorestart: true,
    watch: false,
    max_restarts: 10,
    min_uptime: '10s',
    
    // Exponential backoff restart delay
    exp_backoff_restart_delay: 100,
  }]
};
```

### Phase 3: Redis Session Store

#### 3.1 Install Dependencies
```json
{
  "dependencies": {
    "connect-redis": "^7.1.0",
    "redis": "^4.6.0"
  }
}
```

#### 3.2 Update middleware.js
```javascript
import RedisStore from 'connect-redis'
import { createClient } from 'redis'

// Create Redis client
const redisClient = createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
  legacyMode: false
})

redisClient.connect().catch(console.error)

// Configure session with Redis store
export function createSessionMiddleware(config) {
  return session({
    store: new RedisStore({ client: redisClient }),
    secret: config.session.secret,
    resave: false,
    saveUninitialized: false,
    name: config.session.name,
    cookie: {
      secure: true,
      httpOnly: true,
      maxAge: 1000 * 60 * 60 * 24 // 24 hours
    }
  })
}
```

### Phase 4: Socket.IO Cluster Adapter

#### 4.1 Update io.js
```javascript
import { createAdapter } from '@socket.io/cluster-adapter'
import { setupWorker } from '@socket.io/sticky'

export function configureSocketIO(server, sessionMiddleware, config) {
  const io = new Server(server, {
    serveClient: false,
    path: DEFAULTS.IO_PATH,
    cors: config.getCorsConfig(),
  })

  // Enable cluster adapter
  io.adapter(createAdapter())
  
  // Setup sticky worker
  setupWorker(io)

  // Share session with io sockets
  io.use((socket, next) => {
    sessionMiddleware(socket.request, socket.request.res || {}, next)
  })

  return io
}
```

### Phase 5: Docker Compose Updates

#### 5.1 Add Redis Service
```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: webssh2-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes
    networks:
      - webssh2-network

  nginx-webssh2:
    depends_on:
      - redis
    environment:
      REDIS_URL: redis://redis:6379
      PM2_INSTANCES: 4  # Or 'max' for all CPU cores

volumes:
  redis-data:
```

### Phase 6: Health Checks and Monitoring

#### 6.1 PM2 Health Check Endpoint
```javascript
// Add to routes.js
router.get('/health/pm2', (req, res) => {
  const instanceId = process.env.NODE_APP_INSTANCE || '0'
  res.json({
    status: 'healthy',
    instance: instanceId,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    pid: process.pid
  })
})
```

#### 6.2 Update healthcheck.sh
```bash
#!/bin/bash
# Check PM2 status
pm2 list || exit 1

# Check if WebSSH2 processes are running
pm2 show webssh2 || exit 1

# Check NGINX
curl -f http://localhost/health || exit 1
```

## Production Considerations

### FIPS Compliance
- Ensure PM2 and Redis comply with FIPS 140-2 requirements
- Use FIPS-validated Redis build if available
- Configure Redis with TLS for encrypted communication

### Resource Limits
```yaml
deploy:
  resources:
    limits:
      memory: 2G  # Increase for multiple processes
      cpus: '4.0'  # Allow multiple CPU cores
```

### Monitoring and Logging
- Use PM2 Plus for advanced monitoring
- Configure centralized logging with PM2 log rotation
- Set up alerts for process restarts and memory limits

### Graceful Shutdown
```javascript
process.on('SIGINT', async () => {
  // Close SSH connections gracefully
  await closeAllConnections()
  
  // Notify PM2 that we're ready to exit
  process.exit(0)
})

// Signal PM2 that process is ready
process.send('ready')
```

## Testing Strategy

### 1. Load Testing
- Use Artillery or K6 to simulate multiple concurrent connections
- Test WebSocket connection persistence during PM2 reloads
- Verify session persistence across worker restarts

### 2. Failover Testing
- Kill individual worker processes
- Verify automatic restart and connection recovery
- Test zero-downtime deployments

### 3. Performance Benchmarks
- Compare single-process vs multi-process performance
- Measure CPU utilization across cores
- Monitor memory usage per worker

## Migration Path

### Step 1: Development Environment
1. Implement changes in development docker-compose
2. Test with PM2 in development mode (`pm2-dev`)
3. Verify all functionality works correctly

### Step 2: Staging Deployment
1. Deploy to staging environment with 2 workers
2. Run comprehensive test suite
3. Monitor for 24-48 hours

### Step 3: Production Rollout
1. Deploy with gradual rollout strategy
2. Start with 2 workers, increase based on load
3. Monitor metrics and adjust configuration

## Alternative: Kubernetes-Native Approach

Instead of PM2, consider Kubernetes-native horizontal scaling:
- Use Kubernetes HPA (Horizontal Pod Autoscaler)
- Implement readiness/liveness probes
- Use Redis for session storage
- Let Kubernetes handle process management

Benefits:
- Cloud-native architecture
- Better integration with Kubernetes ecosystem
- Simplified container (single process)
- Platform-managed scaling

## References

- [PM2 Cluster Mode Documentation](https://pm2.keymetrics.io/docs/usage/cluster-mode/)
- [Socket.IO PM2 Documentation](https://socket.io/docs/v4/pm2/)
- [PM2 Load Balancing Guide](https://pm2.io/docs/runtime/guide/load-balancing/)
- [Socket.IO Using Multiple Nodes](https://socket.io/docs/v4/using-multiple-nodes/)
- [Redis Session Store](https://github.com/tj/connect-redis)

## Conclusion

Implementing PM2 clustering will significantly improve the performance and scalability of nginx-webssh2. The recommended approach is to use @socket.io/pm2 with Redis session storage for the most robust solution. This implementation should be thoroughly tested before production deployment.

For future consideration, a Kubernetes-native approach may provide better long-term scalability and cloud compatibility.