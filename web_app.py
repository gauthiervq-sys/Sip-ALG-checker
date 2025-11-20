#!/usr/bin/env python3
"""
Flask Web Application for SIP ALG Checker
Provides a user-friendly web interface for checking SIP ALG status and monitoring network quality.
"""

from flask import Flask, render_template, jsonify, request
import threading
import time
from sip_alg_checker import SIPALGChecker, NetworkMonitor

app = Flask(__name__)

# Global variable to store monitoring state
monitor_thread = None
monitor_results = {
    'running': False,
    'stats': None,
    'error': None
}
monitor_lock = threading.Lock()


def run_monitor(target_host, duration, interval):
    """Run network monitoring in a background thread"""
    global monitor_results
    
    try:
        with monitor_lock:
            monitor_results['running'] = True
            monitor_results['error'] = None
        
        monitor = NetworkMonitor(target_host)
        start_time = time.time()
        
        while (time.time() - start_time) < duration:
            with monitor_lock:
                if not monitor_results['running']:
                    break
            
            monitor.measure_once()
            stats = monitor.get_stats()
            
            with monitor_lock:
                monitor_results['stats'] = stats
            
            time.sleep(interval)
        
        # Final update
        with monitor_lock:
            monitor_results['stats'] = monitor.get_stats()
        
    except Exception as e:
        with monitor_lock:
            monitor_results['error'] = str(e)
    finally:
        with monitor_lock:
            monitor_results['running'] = False


@app.route('/')
def index():
    """Render the main dashboard"""
    return render_template('index.html')


@app.route('/api/check-alg', methods=['POST'])
def check_alg():
    """Check for SIP ALG interference"""
    try:
        data = request.get_json() or {}
        local_ip = data.get('local_ip')
        
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


@app.route('/api/monitor', methods=['POST'])
def start_monitor():
    """Start network monitoring"""
    global monitor_thread, monitor_results
    
    try:
        data = request.get_json() or {}
        target_host = data.get('target_host', '8.8.8.8')
        duration = int(data.get('duration', 60))
        interval = int(data.get('interval', 1))
        
        # Check if monitoring is already running
        with monitor_lock:
            if monitor_results['running']:
                return jsonify({
                    'success': False,
                    'error': 'Monitoring is already running'
                }), 400
            
            # Reset results
            monitor_results = {
                'running': True,
                'stats': None,
                'error': None
            }
        
        # Start monitoring in a background thread
        monitor_thread = threading.Thread(
            target=run_monitor,
            args=(target_host, duration, interval)
        )
        monitor_thread.daemon = True
        monitor_thread.start()
        
        return jsonify({
            'success': True,
            'message': f'Monitoring started for {target_host}',
            'duration': duration,
            'interval': interval
        })
    except Exception as e:
        with monitor_lock:
            monitor_results['running'] = False
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/monitor/status', methods=['GET'])
def monitor_status():
    """Get current monitoring status and results"""
    global monitor_results
    
    with monitor_lock:
        return jsonify({
            'running': monitor_results['running'],
            'stats': monitor_results['stats'],
            'error': monitor_results['error']
        })


@app.route('/api/monitor/stop', methods=['POST'])
def stop_monitor():
    """Stop the running monitor"""
    global monitor_results
    
    with monitor_lock:
        if not monitor_results['running']:
            return jsonify({
                'success': False,
                'error': 'No monitoring is currently running'
            }), 400
        
        monitor_results['running'] = False
    
    return jsonify({
        'success': True,
        'message': 'Monitoring stopped'
    })


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='SIP ALG Checker Web Interface')
    parser.add_argument('--host', type=str, default='0.0.0.0',
                        help='Host to bind to (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=5000,
                        help='Port to bind to (default: 5000)')
    parser.add_argument('--debug', action='store_true',
                        help='Run in debug mode')
    
    args = parser.parse_args()
    
    print(f"Starting SIP ALG Checker Web Interface on http://{args.host}:{args.port}")
    app.run(host=args.host, port=args.port, debug=args.debug)
