"""A NeuroMechFly with every biological joint actuated: legs for walking, plus head, proboscis,
antennae, abdomen and wings for feeding, grooming and (later) flight."""
import numpy as np
from flygym.anatomy import Skeleton, JointPreset, ActuatedDOFPreset, AxisOrder, JointDOF, LEGS
from flygym.compose import NeuroMechFly
from flygym.compose.fly.base_fly import ActuatorType
from flygym.compose.pose import KinematicPosePreset
from flygym_demo.complex_terrain.common import PASSIVE_TARSAL_LINKS

LEG_PREFIXES = ("lf_", "lm_", "lh_", "rf_", "rm_", "rh_")

def make_full_fly(name="fly", adhesion_gain=40.0, colorize=True):
    neutral_pose = KinematicPosePreset.NEUTRAL.get_pose_by_axis_order(AxisOrder.YAW_PITCH_ROLL)
    skeleton = Skeleton(axis_order=AxisOrder.YAW_PITCH_ROLL, joint_preset=JointPreset.ALL_BIOLOGICAL)
    fly = NeuroMechFly(name=name)
    joints = fly.add_joints(skeleton, neutral_pose=neutral_pose, stiffness=0.05, damping=0.06)
    for jointdof, joint in joints.items():
        if jointdof.child.link in PASSIVE_TARSAL_LINKS:
            joint.stiffness[0] = 7.5; joint.damping[0] = 1e-2
    legs_active = set(skeleton.get_actuated_dofs_from_preset(ActuatedDOFPreset.LEGS_ACTIVE_ONLY))
    actuated = [d for d in skeleton.get_actuated_dofs_from_preset(ActuatedDOFPreset.ALL)
                if (d in legs_active) or not d.child.name.startswith(LEG_PREFIXES)]
    fly.add_actuators(actuated, ActuatorType.POSITION, neutral_input=neutral_pose, kp=45.0, forcerange=(-65.0, 65.0))
    fly.add_leg_adhesion(gain=adhesion_gain)
    if colorize:
        fly.colorize()
    return fly

class FullBodyActions:
    """Builds the full actuator target vector: legs from the walking controller, everything else from poses."""
    def __init__(self, fly, steps):
        self.dofs = fly.get_actuated_jointdofs_order("position")
        self.n = len(self.dofs)
        self.leg_idx = [i for i, d in enumerate(self.dofs) if d.child.name.startswith(LEG_PREFIXES)]
        self.leg_dofs = [self.dofs[i] for i in self.leg_idx]
        lookup = fly.get_pose_lookup(KinematicPosePreset.NEUTRAL)
        self.neutral = np.array([lookup.get(d.name, 0.0) for d in self.dofs], dtype=float)
        self.stand = self.neutral.copy()
        self.stand[self.leg_idx] = steps.default_pose_by_dof_order(self.leg_dofs)
        self.index = {(d.parent.name, d.child.name, d.axis.value): i for i, d in enumerate(self.dofs)}

    def i(self, parent, child, axis):
        return self.index[(parent, child, axis)]

    def with_legs(self, leg_angles):
        a = self.stand.copy(); a[self.leg_idx] = leg_angles; return a
