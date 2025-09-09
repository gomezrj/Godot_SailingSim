# README

This is the first (complete) iteration of the sailboat
controller implementation in Godot. It includes point actuated
forces in accordance to theoretical models. Its limitation
lies in the point actuation of forces and the moments
this generates, which make the boat uncontrollable comfortably.

To fix this, newer iterations based on more realistic application
of forces are needed, in particular we will model these forces
on individual points of the sail and hull, and therefore make
them act more realistically and spread throughout the boat itself.

Hopefully this will eliminate some of the jerkiness and the
discomfort in controlling the boat. If not, then the next
idea for an iteration is to forcedly control the boat's point
of force application and to manually make it behave the way we
want and the way the player should expect.


# DEPRECATED

This is a backup of the sailboat controller at the stage of
having implemented aerodynamic, hydrodynamic, and damping
forces. It should now feel much better, but it doesn't.
The model is almost complete, and now we should tamper with
the curves and the numbers themselves. In particular:

1. The leeway angles for the keel and rudder feel off. The boat
easily loses control, and when traveling in a straight line,
the lift of the keel and the sudden change in direction of the
leeway angle is a problem that destabilizes the boat.

To solve this we can:
	1. Try to correct the angles (i.e. not use the horizontal
	plane but rather the boat plane to compute the angles).
	2. Compute the forces with the defined values to see how
	the lift from the sails and the appendages balances out
	3. Experiment with the coefficient curves to see if this
	fixes anything (I expect to have the same curves, but with
	different values).
	4. Debug.

2. The boat tends to turn itself into the wind, as pushed by
the sails. The sails should not make the boat rotate, as it
is a lot heavier and also water resists this rotation.

To solve this, we may try:
	1. Add two hull drag points along the centerline that
	help produce an anti-yaw torque (ChatGPT). This gives the
	hull a place to "grab" the water.
	2. Fix the keel and rudder's inflow: they should not always
	just see the linear_velocity, but the local flow of the
	boat. This is the velocity plus the rotational flow of
	water (ChatGPT)
	3. Tweak the CE vs CLR positioning (ChatGPT).
	4. Tweak the yaw damping settings.
	5. Tweak the keel and rudder curves, giving the rudder real
	"bite" on the water (ChatGPT).
	6. Debug.



