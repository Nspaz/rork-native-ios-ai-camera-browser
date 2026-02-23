import Foundation

nonisolated enum CameraInterceptScript {
    static let source: String = """
    (function() {
        'use strict';

        var DEVICE_ID = 'com.apple.avfoundation.avcapturedevice.built-in_video:1';
        var GROUP_ID = 'com.apple.avfoundation.avcapturedevice.built-in_video:1';
        var LABEL = 'Front Camera';

        if (!navigator.mediaDevices) {
            try {
                Object.defineProperty(navigator, 'mediaDevices', {
                    value: {},
                    writable: true,
                    configurable: true
                });
            } catch(e) { return; }
        }

        var origGUM = navigator.mediaDevices.getUserMedia
            ? navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices)
            : null;
        var origEnum = navigator.mediaDevices.enumerateDevices
            ? navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices)
            : null;

        var canvas = document.createElement('canvas');
        canvas.width = 1280;
        canvas.height = 720;
        var ctx = canvas.getContext('2d');
        ctx.fillStyle = '#1a1a1a';
        ctx.fillRect(0, 0, 1280, 720);

        var baseStream = null;
        var frameImg = new Image();

        window.__vcam_pushFrame = function(b64) {
            frameImg.src = 'data:image/jpeg;base64,' + b64;
        };

        frameImg.onload = function() {
            try { ctx.drawImage(frameImg, 0, 0, 1280, 720); } catch(e) {}
        };

        window.addEventListener('message', function(e) {
            if (e.data && e.data.type === '__vcam_frame') {
                frameImg.src = 'data:image/jpeg;base64,' + e.data.d;
            }
        });

        var origPushFrame = window.__vcam_pushFrame;
        window.__vcam_pushFrame = function(b64) {
            origPushFrame(b64);
            for (var i = 0; i < window.frames.length; i++) {
                try { window.frames[i].postMessage({type: '__vcam_frame', d: b64}, '*'); } catch(e) {}
            }
        };

        function getStream() {
            if (!baseStream) {
                baseStream = canvas.captureStream(30);
            }
            return baseStream;
        }

        function patchTrack(track) {
            var origSettings = track.getSettings.bind(track);
            track.getSettings = function() {
                var s = origSettings();
                return Object.assign({}, s, {
                    deviceId: DEVICE_ID,
                    groupId: GROUP_ID,
                    facingMode: 'user',
                    width: 1280,
                    height: 720,
                    frameRate: 30,
                    aspectRatio: 1.7778
                });
            };
            if (track.getCapabilities) {
                track.getCapabilities = function() {
                    return {
                        deviceId: DEVICE_ID,
                        groupId: GROUP_ID,
                        facingMode: ['user'],
                        width: {min: 1, max: 4032},
                        height: {min: 1, max: 3024},
                        frameRate: {min: 1, max: 60},
                        aspectRatio: {min: 0.000926, max: 4032}
                    };
                };
            }
            try {
                Object.defineProperty(track, 'label', {
                    get: function() { return LABEL; },
                    configurable: true
                });
            } catch(e) {}
        }

        navigator.mediaDevices.getUserMedia = function(constraints) {
            if (!constraints || !constraints.video) {
                if (origGUM) return origGUM(constraints);
                return Promise.reject(new DOMException('getUserMedia not available', 'NotSupportedError'));
            }

            return new Promise(function(resolve, reject) {
                try {
                    var stream = getStream();
                    var tracks = stream.getVideoTracks().map(function(t) { return t.clone(); });
                    var result = new MediaStream(tracks);

                    result.getVideoTracks().forEach(patchTrack);

                    if (constraints.audio && origGUM) {
                        origGUM({audio: constraints.audio})
                            .then(function(audioStream) {
                                audioStream.getAudioTracks().forEach(function(t) { result.addTrack(t); });
                                resolve(result);
                            })
                            .catch(function() { resolve(result); });
                    } else {
                        resolve(result);
                    }
                } catch(e) {
                    reject(new DOMException('Could not start video source', 'NotReadableError'));
                }
            });
        };

        navigator.mediaDevices.enumerateDevices = function() {
            var vCam = {
                deviceId: DEVICE_ID,
                kind: 'videoinput',
                label: LABEL,
                groupId: GROUP_ID,
                toJSON: function() {
                    return {deviceId: this.deviceId, kind: this.kind, label: this.label, groupId: this.groupId};
                }
            };
            if (origEnum) {
                return origEnum().then(function(devices) {
                    var filtered = devices.filter(function(d) { return d.kind !== 'videoinput'; });
                    return [vCam].concat(filtered);
                });
            }
            return Promise.resolve([vCam]);
        };

        if (navigator.mediaDevices.getSupportedConstraints) {
            var origSC = navigator.mediaDevices.getSupportedConstraints.bind(navigator.mediaDevices);
            navigator.mediaDevices.getSupportedConstraints = function() {
                var c = origSC ? origSC() : {};
                return Object.assign({}, c, {
                    width: true, height: true, frameRate: true,
                    facingMode: true, deviceId: true, groupId: true, aspectRatio: true
                });
            };
        }

        try { window.webkit.messageHandlers.vcamReady.postMessage('ready'); } catch(e) {}
    })();
    """
}
