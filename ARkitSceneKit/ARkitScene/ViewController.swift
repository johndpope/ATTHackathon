//
//  ViewController.swift
//  ARkitScene
//
//  Created by Joshua Homann on 6/24/17.
//  Copyright © 2017 josh. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    @IBOutlet weak var textViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var textView: UITextView!
    var userAnchorIds: Set<UUID> = []
    lazy var superman: SCNNode = {
        let scene = SCNScene(named: "art.scnassets/batmanidle.dae")!.rootNode
        let node = SCNNode()
        let wrapper = SCNNode()
        wrapper.transform = SCNMatrix4Rotate(SCNMatrix4MakeScale(0.0025, 0.0025, 0.0025), 0, 1, 0, 0)
        scene.childNodes.forEach { wrapper.addChildNode($0) }
        node.addChildNode(wrapper)
//        let url = Bundle.main.url(forResource: "a", withExtension: "mp4")!
//        let hieght: CGFloat = 9.0/16.0
//        let videoNode = self.createVideoNode(url: url, width: 1, height:hieght).0
//        videoNode.position = .init(0, hieght / 2 + 0.5, 0)
//        node.addChildNode(videoNode)
        return node
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.delegate = self
        sceneView.session.delegate = self
        // Set the scene to the view
        sceneView.scene = SCNScene()
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        sceneView.addGestureRecognizer(recognizer)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(recognizer:)))
        sceneView.addGestureRecognizer(pinch)
//        let right = UISwipeGestureRecognizer(target: self, action: #selector(rightSwipe(recognizer:)))
//        right.direction = .right
//        sceneView.addGestureRecognizer(right)
//        let left = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe(recognizer:)))
//        left.direction = .left
//        sceneView.addGestureRecognizer(left)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(recognizer:)))
//        pan.require(toFail: right)
//        pan.require(toFail: left)
        sceneView.addGestureRecognizer(pan)
        textViewWidthConstraint.constant = .ulpOfOne
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        // Run the view's session
        sceneView.session = ARSession()
        sceneView.session.run(configuration)
        sceneView.showsStatistics = true
        sceneView.scene.rootNode.addChildNode(superman)
        log(text: "start logging")

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }

    @objc func tap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        let normalizedPoint = CGPoint(x: location.x / view.bounds.size.width, y: location.y / view.bounds.size.height)
        let results = sceneView.session.currentFrame?.hitTest(normalizedPoint, types: [.estimatedHorizontalPlane, .existingPlane])
        guard let closest = results?.first else {
            return
        }
        let hitAnchor = ARAnchor(transform: closest.worldTransform)
        userAnchorIds.insert(hitAnchor.identifier)
        sceneView.session.add(anchor: hitAnchor)
    }

    @objc func pinch(recognizer: UIPinchGestureRecognizer) {
        let scale = recognizer.scale
        superman.scale = .init(scale, scale, scale)
    }

    @objc func pan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            superman.removeAllAnimations()
        case .changed:
            let delta = recognizer.translation(in: sceneView)
            let rotationY = delta.x / UIScreen.main.bounds.size.width * CGFloat.pi * 2
            superman.eulerAngles = SCNVector3(0, rotationY, 0)
        case .cancelled, .ended, .failed:
            break
        default:
            break
        }
    }
    
    var isDebugViewVisible = false
    
    func toggleDebugView() {
        if isDebugViewVisible {
            isDebugViewVisible = false
            textViewWidthConstraint.constant = .ulpOfOne
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
        }
        else {
            isDebugViewVisible = true
            textViewWidthConstraint.constant = 200
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
        }
    }

    func createVideoNode(url: URL, width: CGFloat, height: CGFloat) -> (SCNNode, SKVideoNode) {
        let spriteKitScene = SKScene(size: CGSize(width: 1276.0 / 2.0, height: 712.0 / 2.0))
        let videoSpriteKitNode = SKVideoNode(url: url)
        let videoNode = SCNNode()

        videoNode.geometry = SCNPlane(width: width, height: height)

        spriteKitScene.scaleMode = .aspectFill
        videoSpriteKitNode.position = CGPoint(x: spriteKitScene.size.width / 2.0, y: spriteKitScene.size.height / 2.0)
        videoSpriteKitNode.size = spriteKitScene.size
        videoSpriteKitNode.xScale = -1
        spriteKitScene.addChild(videoSpriteKitNode)

        videoNode.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
        videoNode.geometry?.firstMaterial?.isDoubleSided = true

       return (videoNode, videoSpriteKitNode)

    }

    func log(text: CustomStringConvertible) {
        textView.text.append(text.description)
    }
}

extension ViewController: ARSessionDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard userAnchorIds.contains(anchor.identifier) else {
            return nil
        }
        return superman
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let anchor = anchor as? ARPlaneAnchor {
            self.log(text: "Adding plane anchor: \(anchor)")
            let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
            let planeNode = SCNNode(geometry: plane)
            planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
            node.addChildNode(planeNode)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        print(anchor)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print(anchor)
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            self.log(text:"Tracking normal")
        case .notAvailable:
            self.log(text: "Not Available")
        case .limited(let reason):
            self.log(text: "Limited Tracking: \(reason)")
        }
    }
}

