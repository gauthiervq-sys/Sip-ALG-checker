#!/usr/bin/env python3
"""
Web Interface for SIP ALG Checker
A Flask-based web application for checking SIP ALG and monitoring network quality
"""

from flask import Flask, render_template, jsonify, request
from sip_alg_checker import SIPALGChecker, NetworkMonitor
import time

app = Flask(__name__)


@app.route('/')
def index():
    """Render the main web interface"""
    return render_template('index.html')


@app.route('/api/check_alg')
def check_alg():
    """API endpoint to check for SIP ALG"""
    try:
        checker = SIPALGChecker()
        results = checker.check_sip_alg_via_nat()
        return jsonify(results)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/monitor')
def monitor():
    """API endpoint to monitor network quality"""
    try:
        # Get query parameters with defaults
        host = request.args.get('host', '8.8.8.8')
        duration = int(request.args.get('duration', 10))
        
        # Limit duration to prevent long blocking calls
        duration = min(duration, 60)  # Max 60 seconds
        
        # Create monitor and run measurements
        # sample_size should match the expected number of measurements (duration in seconds)
        monitor = NetworkMonitor(target_host=host, sample_size=duration)
        
        start_time = time.time()
        measurement_count = 0
        error_count = 0
        while (time.time() - start_time) < duration:
            try:
                monitor.measure_once()
                measurement_count += 1
            except PermissionError:
                # If ping requires elevated permissions, return helpful error
                return jsonify({
                    'error': 'Network monitoring requires elevated permissions. Please run with sudo or use an alternative monitoring method.',
                    'note': 'The ping3 library requires root/administrator privileges to send ICMP packets.'
                }), 403
            except Exception as e:
                # Track errors but continue with remaining measurements
                error_count += 1
                # If too many errors, fail early
                if error_count > 3 and measurement_count == 0:
                    return jsonify({
                        'error': f'Network monitoring failed: {str(e)}'
                    }), 500
            time.sleep(1)  # 1 second interval
        
        # Check if we got any measurements
        if measurement_count == 0:
            return jsonify({
                'error': 'No successful measurements could be made. Please check network connectivity and permissions.'
            }), 500
        
        # Get final statistics
        stats = monitor.get_stats()
        
        # Add quality assessment
        quality = "EXCELLENT"
        if stats['packet_loss_percent'] > 1 or stats['jitter_ms'] > 30:
            quality = "POOR"
        elif stats['packet_loss_percent'] > 0.5 or stats['jitter_ms'] > 20:
            quality = "FAIR"
        elif stats['jitter_ms'] > 10:
            quality = "GOOD"
        
        stats['quality'] = quality
        
        return jsonify(stats)
    except ValueError as e:
        return jsonify({'error': f'Invalid parameter: {str(e)}'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("Starting SIP ALG Checker Web Interface...")
    print("Open your browser and navigate to: http://localhost:5000")
    print("\nWARNING: This is running in debug mode for development.")
    print("For production use, set debug=False and use a production WSGI server.")
    app.run(debug=True, host='0.0.0.0', port=5000)
