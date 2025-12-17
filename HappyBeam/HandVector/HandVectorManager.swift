//
//  HandVectorManager.swift
//  HappyBeam
//
//  Ported from HandVector
//

import RealityKit
import ARKit

@MainActor
public class HandVectorManager: ObservableObject {
    public static let shared = HandVectorManager()
    
    @Published public var leftHand: HVHandInfo?
    @Published public var rightHand: HVHandInfo?
    
    public var leftHandEntity: Entity?
    public var rightHandEntity: Entity?
    
    public let rootEntity = Entity()
    
    public var isSkeletonVisible: Bool = false {
        didSet {
            leftHandEntity?.isEnabled = isSkeletonVisible
            rightHandEntity?.isEnabled = isSkeletonVisible
        }
    }
    
    public init() {
        rootEntity.name = "HandVectorRoot"
    }
    
    public func update(left: HandAnchor?, right: HandAnchor?) {
        if let left = left, left.isTracked {
            self.leftHand = HVHandInfo(handAnchor: left)
        } else {
            self.leftHand = nil
        }
        
        if let right = right, right.isTracked {
            self.rightHand = HVHandInfo(handAnchor: right)
        } else {
            self.rightHand = nil
        }
        
        updateSkeleton()
    }
    
    func updateSkeleton() {
        if isSkeletonVisible {
            if leftHandEntity == nil {
                leftHandEntity = createSkeletonEntity()
                rootEntity.addChild(leftHandEntity!)
            }
            if rightHandEntity == nil {
                rightHandEntity = createSkeletonEntity()
                rootEntity.addChild(rightHandEntity!)
            }
            
            updateSkeletonEntity(entity: leftHandEntity, hand: leftHand)
            updateSkeletonEntity(entity: rightHandEntity, hand: rightHand)
        } else {
            leftHandEntity?.isEnabled = false
            rightHandEntity?.isEnabled = false
        }
    }
    
    func createSkeletonEntity() -> Entity {
        let root = Entity()
        for joint in HandSkeleton.JointName.allCases {
            let entity = ModelEntity(mesh: .generateSphere(radius: 0.005), materials: [SimpleMaterial(color: .green, isMetallic: false)])
            entity.name = joint.name
            root.addChild(entity)
        }
        return root
    }
    
    func updateSkeletonEntity(entity: Entity?, hand: HVHandInfo?) {
        guard let entity = entity else { return }
        guard let hand = hand else {
            entity.isEnabled = false
            return
        }
        entity.isEnabled = true
        entity.transform.matrix = hand.transform
        
        for joint in HandSkeleton.JointName.allCases {
            if let child = entity.findEntity(named: joint.name), let jointInfo = hand.allJoints[joint] {
                child.transform.matrix = jointInfo.transform
            }
        }
    }
}
