#!/usr/bin/env python3
"""
Web interface for SIP ALG Checker Tool
Provides a modern web UI for checking SIP ALG status and monitoring network quality
"""

from flask import Flask, render_template, jsonify, request
import threading
import time
from sip_alg_checker import SIPALGChecker, NetworkMonitor

app = Flask(__name__)

# Store active monitoring sessions
active_monitors = {}
monitor_lock = threading.Lock()


@app.route('/')
def index():
    """Serve the main dashboard page"""
    return render_template('index.html')


@app.route('/api/check-alg', methods=['POST'])
def check_alg():
    """API endpoint to check SIP ALG status"""
    try:
        data = request.get_json() or {}
        local_ip = data.get('local_ip', None)
        
        checker = SIPALGChecker(local_ip=local_ip)
        results = checker.check_sip_alg_via_nat()
        
        return jsonify({
            'success': True,
            'results': results
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/start-monitor', methods=['POST'])
def start_monitor():
    """API endpoint to start network monitoring"""
    try:
        data = request.get_json()
        target_ip = data.get('target_ip')
        duration = int(data.get('duration', 60))
        
        if not target_ip:
            return jsonify({
                'success': False,
                'error': 'Target IP is required'
            }), 400
        
        # Create a unique session ID
        session_id = f"{target_ip}_{int(time.time())}"
        
        # Create monitor
        monitor = NetworkMonitor(target_host=target_ip)
        
        with monitor_lock:
            active_monitors[session_id] = {
                'monitor': monitor,
                'target': target_ip,
                'duration': duration,
                'start_time': time.time(),
                'running': True,
                'measurements': []
            }
        
        # Start monitoring in background thread
        thread = threading.Thread(
            target=_monitor_worker,
            args=(session_id, duration),
            daemon=True
        )
        thread.start()
        
        return jsonify({
            'success': True,
            'session_id': session_id
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/monitor-status/<session_id>', methods=['GET'])
def monitor_status(session_id):
    """Get the current status of a monitoring session"""
    try:
        with monitor_lock:
            if session_id not in active_monitors:
                return jsonify({
                    'success': False,
                    'error': 'Session not found'
                }), 404
            
            session = active_monitors[session_id]
            monitor = session['monitor']
            stats = monitor.get_stats()
            
            elapsed = time.time() - session['start_time']
            remaining = max(0, session['duration'] - elapsed)
            
            return jsonify({
                'success': True,
                'running': session['running'],
                'elapsed': round(elapsed, 2),
                'remaining': round(remaining, 2),
                'stats': stats
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/stop-monitor/<session_id>', methods=['POST'])
def stop_monitor(session_id):
    """Stop a monitoring session"""
    try:
        with monitor_lock:
            if session_id not in active_monitors:
                return jsonify({
                    'success': False,
                    'error': 'Session not found'
                }), 404
            
            active_monitors[session_id]['running'] = False
            
        return jsonify({
            'success': True,
            'message': 'Monitoring stopped'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


def _monitor_worker(session_id, duration):
    """Background worker for monitoring"""
    start_time = time.time()
    
    while True:
        with monitor_lock:
            if session_id not in active_monitors:
                break
            
            session = active_monitors[session_id]
            if not session['running']:
                break
            
            monitor = session['monitor']
        
        # Check if duration exceeded
        if time.time() - start_time >= duration:
            with monitor_lock:
                if session_id in active_monitors:
                    active_monitors[session_id]['running'] = False
            break
        
        # Perform measurement
        monitor.measure_once()
        time.sleep(1)  # 1 second interval
    
    # Clean up after some time
    time.sleep(60)  # Keep session data for 1 minute after completion
    with monitor_lock:
        if session_id in active_monitors:
            del active_monitors[session_id]


if __name__ == '__main__':
    print("=" * 60)
    print("SIP ALG Checker Web Interface")
    print("=" * 60)
    print("Starting web server on http://localhost:5000")
    print("Press Ctrl+C to stop")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
