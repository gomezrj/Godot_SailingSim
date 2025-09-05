extends RigidBody3D

## SAILING BOAT MOVEMENT SCRIPT
# The script models the behavior of a sailing boat controlled through
# player input, and through a simplified model of the real-life
# physics involved in sailing.
#
# INFO: It is not complete and will require the following changes:
# - Adjust the units to fit real life characteristics
# - Adjust the aerodynamic and hydrodynamic curves to desired performance
# - Adjust and clean node structure of Boat
# - Fix the hydrostatic forces model (buoyancy, weight and damping)
# - Provide classes for different elements of the boat and subdivide
#   it for interchangeability of sails, rudders, etc.
# - Review and adjust angle measurements in view of wave effects
#
# NOTE: The last point refers to how angles are not properly computed
# at the moment, as they are computed with respect to horizontal planes.
# For instance, the mainsail vector should be projected onto the boat plane,
# not te horizontal plane. This will have consequences when waves interact
# with the boat after the water shader is completed.


@export_group("Settings")
## Engine toggle
@export var engine_on := true
## Sails toggle
@export var sails := false
## Area of sail surface in square meters (default is 50.0)
@export var sail_area : float = 50.0
## Area of keel surface in square meters (default is 1.50 x 1.20)
@export var keel_area : float = 1.8
## Aread of rudder surface in square meters (default is 0.8)
@export var rudder_area : float = 0.8
## Mass of the boat
@export var _mass : float = 13000
## Gravity the object experiences
@export var _gravity_scale : float = 9.8
## Angular damping forces
@export var yaw_damp : float = 0.0
@export var pitch_damp : float = 0.0
@export var roll_damp : float = 0.0


@export_group("Sail properties")
# Max sail swing left/right
@export var sail_max_open_angle_deg: float = 80.0
# How much the sheet is pulled in (player control)
@export var sail_sheet_angle_deg: float = 45.0
# How strongly sheet resists beyond sheet_angle
@export var sail_stiffness: float = 2.0
# Smoothness of rotation
@export var sail_damping: float = 0.5

@export_group("Speeds")
## Speed of the boat under engine action
@export var move_speed : float = 5
## Speed of rotation
@export var rotation_speed : float = 3
## Speed of the wind
@export var wind_speed : float = 10
## Speed of rotation of the sails in degrees per second
@export var sails_rotation_speed : float = 7
## Speed of rotation of the rudder in degrees per second
@export var rudder_rotation_speed : float = 7

@export_group("Aerodynamic coefficients")
## Behavior of lift coefficient wrt angle of attack of main sail
@export var aero_lift_coefficient_main : Curve
## Behavior of drag coefficient wrt angle of attack of main sail
@export var aero_drag_coefficient_main : Curve

@export_group("Hydrodynamic coefficients")
## Behavior of lift coefficient wrt leeway angle of keel
@export var hydro_lift_coefficient_keel : Curve
## Behavior of drag coefficient wrt leeway angle of keel
@export var hydro_drag_coefficient_keel : Curve
## Behavior of lift coefficient wrt leeway angle of rudder
@export var hydro_lift_coefficient_rudder : Curve
## Behavior of drag coefficient wrt leeway angle of rudder
@export var hydro_drag_coefficient_rudder : Curve


@export_group("Input Actions")
## Name of Input Action to move forwards.
@export var input_motor : String = "motor"
## Name of Input Action to move backwards.
@export var input_reverse : String = "reverse"
## Name of Input Action to move clockwise.
@export var input_torque_right : String = "torque_right"
## Name of Input Action to move anti-clockwise.
@export var input_torque_left : String = "torque_left"
## Name of Input Action to toggle the engine
@export var engine_toggle : String = "engine_toggle"
## Name of Input Action to toggle the sails
@export var sails_toggle : String = "sails_toggle"
## Name of Input Action to rotate the sail right
@export var sails_rotate_right : String = "sails_rotate_right"
## Name of Input Action to rotate the sail left
@export var sails_rotate_left : String = "sails_rotate_left"
## Name of Input Action to rotate the rudder right
@export var rudder_rotate_right : String = "rudder_rotate_right"
## Name of Input Action to rotate the sail left
@export var rudder_rotate_left : String = "rudder_rotate_left"

# Sail-related
var sail_angular_velocity: float = 0.0
var sail_current_angle: float = 0.0  # radians relative to boat forward
var can_rotate_sails_left := true
var can_rotate_sails_right := true
var input_sails := 0.0

# Physical settings
const air_density := 1.2 # in kg/m3
const water_density := 1000.0 # in kg/m3
var wind_direction := Vector3(1.0,0.0,0.0) # we need to continuously feed this to the program after the wind manager is done
var wind := wind_direction*wind_speed
var apparent_wind := Vector3(0.0, 0.0, 0.0) # apparent wind

# Engine-related
var move_direction : Vector3
var engine_move_direction : Vector3
var input_dir

# Rudder-related
var can_rotate_rudder_left := true
var can_rotate_rudder_right := true
var rudder_angle := 0.0
var input_rudder := 0.0

# Aerodynamic forces and parameters
var angle_of_attack_main := 0.0

var aerodynamic_lift_main_force := 0.0
var aerodynamic_drag_main_force := 0.0
var aerodynamic_lift_main_dir : Vector3
var aerodynamic_drag_main_dir : Vector3

var total_aerodynamic_force_main : Vector3

# Hydrodynamic forces and parameters
var leeway_angle := 0.0
var leeway_angle_rudder := 0.0

var hydrodynamic_lift_keel_force := 0.0
var hydrodynamic_drag_keel_force := 0.0
var hydrodynamic_lift_keel_dir : Vector3
var hydrodynamic_drag_keel_dir : Vector3

var hydrodynamic_lift_rudder_force := 0.0
var hydrodynamic_drag_rudder_force := 0.0
var hydrodynamic_lift_rudder_dir : Vector3
var hydrodynamic_drag_rudder_dir : Vector3

var total_hydrodynamic_force_keel : Vector3
var total_hydrodynamic_force_rudder : Vector3


# Some references we need
var mast_pivot_point := get_node_or_null("Boat_model/Sailboat/BackHMast_pivotpoint") as Node3D
var rudder_pivot_point := get_node_or_null("Boat_model/Sailboat/Rudder_pivotpoint") as Node3D
var CE := get_node_or_null("Boat_model/Sailboat/BackHMast_pivotpoint/CE") as Node3D
var CE_L := get_node_or_null("Boat_model/Sailboat/BackHMast_pivotpoint/CE/CE_L") as Node3D
var CE_R := get_node_or_null("Boat_model/Sailboat/BackHMast_pivotpoint/CE/CE_R") as Node3D
var CLR_keel := get_node_or_null("Boat_model/Sailboat/CLR_keel") as Node3D
var CLR_rudder := get_node_or_null("Boat_model/Sailboat/Rudder_pivotpoint/CLR_rudder") as Node3D
var CG := get_node_or_null("Boat_model/Sailboat/CG") as Node3D
var MainSailExtreme := get_node_or_null("Boat_model/Sailboat/BackHMast_pivotpoint/MainSailExtreme") as Node3D

func _ready() -> void:
	mast_pivot_point = $Boat_model/Sailboat/BackHMast_pivotpoint
	rudder_pivot_point = $Boat_model/Sailboat/Rudder_pivotpoint
	CE = $Boat_model/Sailboat/BackHMast_pivotpoint/CE
	CE_L = $Boat_model/Sailboat/BackHMast_pivotpoint/CE/CE_L
	CE_R = $Boat_model/Sailboat/BackHMast_pivotpoint/CE/CE_R
	CLR_keel = $Boat_model/Sailboat/CLR_keel	
	CLR_rudder = $Boat_model/Sailboat/Rudder_pivotpoint/CLR_rudder
	CG = $Boat_model/Sailboat/CG
	MainSailExtreme = $Boat_model/Sailboat/BackHMast_pivotpoint/MainSailExtreme
	
	# We assign the center of mass
	# set_center_of_mass_mode(RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM)
	# set_center_of_mass(CG.position)
	# Change some physical values
	set_mass(_mass)
	set_gravity_scale(_gravity_scale)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("engine_toggle"):
		_toggle_engine()
	if event.is_action_pressed("sails_toggle"):
		_toggle_sails()

func _physics_process(delta: float) -> void:
	# Custom weight NEEDS TO BE CHANGED
	# apply_central_force(_gravity_scale*mass*Vector3.UP)
	# apply_force(_gravity_scale*mass*Vector3.DOWN,CG.global_position)
	
	## Handle input
	input_dir = Input.get_vector(input_torque_right, input_torque_left, input_motor, input_reverse)
	input_sails = Input.get_axis(sails_rotate_left, sails_rotate_right)
	input_rudder = Input.get_axis(rudder_rotate_right, rudder_rotate_left)
	
	## Handling of the boat - controls and player input
	
	# Engine input
	if engine_on == true:
		engine_move_direction = -1*global_transform.basis.z
		
		if input_motor or input_reverse:
			apply_central_force(engine_move_direction*move_speed*input_dir.y)
		if input_torque_left or input_torque_right:
			apply_torque(transform.basis.y*input_dir.x*rotation_speed)
	
	# Rudder rotation wrt boat
	if input_rudder and rudder_pivot_point != null:
		if can_rotate_rudder_left and input_rudder >= 0:
			rudder_pivot_point.rotate(Vector3(0.0,0.0,1.0),deg_to_rad(rudder_rotation_speed*delta*input_rudder))
			rudder_angle += deg_to_rad(rudder_rotation_speed*delta*input_rudder)
		if can_rotate_rudder_right and input_rudder <= 0:
			rudder_pivot_point.rotate(Vector3(0.0,0.0,1.0),deg_to_rad(rudder_rotation_speed*delta*input_rudder))
			rudder_angle += deg_to_rad(rudder_rotation_speed*delta*input_rudder)
	
	# Anchor
	
	## Aerodynamic forces on sails
	if sails:
		apply_force(total_aerodynamic_force_main, CE.global_position)
	## Hydrodynamic forces
	apply_force(total_hydrodynamic_force_keel, CLR_keel.global_position)
	apply_force(total_hydrodynamic_force_rudder, CLR_rudder.global_position)
	## Aerostatic forces on hull
	
	## Hydrostatic forces (buoyancy, weight?)
	
	## Buoyancy forces (need to adjust the constant 20 and the logic)
	# The constant 20 should depend on the mass, volume of water displaced
	# etcetera - look at the bouyancy formula to get a better model
	
	if $Floater1.global_transform.origin.y <= 0:
		apply_force(Vector3.UP*water_density*get_gravity_scale()*get_mass()/300*-$Floater1.global_transform.origin, $Floater1.global_transform.origin-global_transform.origin)
	if $Floater2.global_transform.origin.y <= 0:
		apply_force(Vector3.UP*water_density*get_gravity_scale()*get_mass()/300*-$Floater2.global_transform.origin, $Floater2.global_transform.origin-global_transform.origin)
	if $Floater3.global_transform.origin.y <= 0:
		apply_force(Vector3.UP*water_density*get_gravity_scale()*get_mass()/300*-$Floater3.global_transform.origin, $Floater3.global_transform.origin-global_transform.origin)
	if $Floater4.global_transform.origin.y <= 0:
		apply_force(Vector3.UP*water_density*get_gravity_scale()*get_mass()/300*-$Floater4.global_transform.origin, $Floater4.global_transform.origin-global_transform.origin)
	
	## Now some managers in the physics process
	_rudder_rotation_manager()
	aerodynamic_forces_manager()
	hydrodynamic_forces_manager()
	sail_manager(delta)
	damping_manager()
	
	# DebugDraw3D.draw_arrow(position, position+(total_aerodynamic_force_main+total_hydrodynamic_force_keel)*0.001, Color.ORANGE)
	


### Finally some functions that clean the code before
## Input-related
# Engine toggle
func _toggle_engine():
	engine_on = !engine_on
	return

# Sails toggle
func _toggle_sails():
	sails = !sails
	return

# Sails controls
func sail_manager(delta):
	var horizontal_plane = Plane(Vector3(0.0, 1.0, 0.0))
	var boat_forward = horizontal_plane.project(global_transform.basis.z).normalized()
	var mainsail_vector := -horizontal_plane.project(Vector3(MainSailExtreme.global_position - mast_pivot_point.global_position)).normalized()
	var wind_angle_to_boat := 0.0
	var wind_angle_to_sail := apparent_wind.normalized().signed_angle_to(mainsail_vector, Vector3.UP)
	var target_angle := 0.0
	var sail_torque := 0.0
	var overrotation_control = mainsail_vector.angle_to(boat_forward)
	
	# The function does not work correctly but it is well structured
	
	# Set the slack to desired angle wrt boat
	sail_sheet_angle_deg += (sails_rotation_speed)*delta*input_sails
	sail_sheet_angle_deg = clampf(sail_sheet_angle_deg, 0.0, sail_max_open_angle_deg)
	
	if apparent_wind.length() < 0.1 or !sails:
		return
	
	# Compute the angle from the boat's forward direction to the wind and the sails angle
	wind_angle_to_boat = apparent_wind.normalized().signed_angle_to(boat_forward, Vector3.UP)
	sail_current_angle = wind_angle_to_sail-wind_angle_to_boat # angle of sails wrt boat, positive is right, negative is left
	if abs(sail_current_angle) > PI/2:
		sail_current_angle -= sign(sail_current_angle)*PI*2
	# Set the target angle of the sail
	if wind_angle_to_boat >= -PI/2 and wind_angle_to_boat <= PI/2:
		# downwind
		target_angle = sign(wind_angle_to_boat)*deg_to_rad(sail_sheet_angle_deg)
	else:
		# windward
		target_angle = clampf(sign(wind_angle_to_boat)*PI-wind_angle_to_boat, deg_to_rad(-sail_sheet_angle_deg), deg_to_rad(sail_sheet_angle_deg))
	
	# Compute torque
	sail_torque = (target_angle - sail_current_angle) * sail_stiffness
	sail_angular_velocity += sail_torque * delta
	sail_angular_velocity *= exp(-sail_damping * delta)
	# Now bug control: if the target has been overshot, stop rotating
	if overrotation_control > deg_to_rad(sail_max_open_angle_deg+5):
		sail_angular_velocity = -sail_angular_velocity
	# Apply torque
	mast_pivot_point.rotate(Vector3.FORWARD,sail_angular_velocity)

# rudder control
func _can_rotate_rudder_right():
	if rudder_angle <= -1*PI/4:
		can_rotate_rudder_right = false
	else:
		can_rotate_rudder_right = true

func _can_rotate_rudder_left():
	if rudder_angle >= PI/4:
		can_rotate_rudder_left = false
	else:
		can_rotate_rudder_left = true

func _rudder_rotation_manager():
	if abs(input_rudder) <= 0.1:
		return
	_can_rotate_rudder_left()
	_can_rotate_rudder_right()
	return

## Aerodynamic forces manager
# This function is designed to compute all the aerodynamic forces acting on the boat.
# There are four points we should take into account:
#
# NOTE: The angle-related variables need to be revised. The model would work like this
# with 2D angles, but it could break in 3D.
# NOTE: The forces are applied in the CORRECT directions. This does not need to change.
# NOTE: We have to put units on the variables in all the script.
# NOTE: Sails swapping is not implemented. To this end:
# - Need to change sail to a rigidbody or something of the sort
# - Need to change joints from sail to boat
# - Need to model ropes that move the sails
#
func aerodynamic_forces_manager():
	var raw_angle := 0.0
	var mainsail_vector := Vector3(MainSailExtreme.global_position - mast_pivot_point.global_position)
	var mainsail_inclination := global_transform.basis.y
	var inclination_angle_to_apparent_wind := 0.0
	var horizontal_plane = Plane(Vector3(0.0, 1.0, 0.0))
	
	# Compute apparent wind
	apparent_wind = wind_speed*wind_direction.normalized() - horizontal_plane.project(linear_velocity)
	inclination_angle_to_apparent_wind = abs(sin(apparent_wind.angle_to(mainsail_inclination)))
	# Compute angle of attack
	angle_of_attack_main = apparent_wind.angle_to(mainsail_vector)
	# Compute lift
	raw_angle = apparent_wind.signed_angle_to(mainsail_vector, Vector3(0,1,0))
	if raw_angle <= 0:
		# aerodynamic_lift_main_dir = (CE_R.global_position - CE.global_position).normalized()
		aerodynamic_lift_main_dir = -apparent_wind.cross(mainsail_inclination).normalized()
	else:
		# aerodynamic_lift_main_dir = (CE_L.global_position - CE.global_position).normalized()
		aerodynamic_lift_main_dir = apparent_wind.cross(mainsail_inclination).normalized()
	aerodynamic_lift_main_force = aero_lift_coefficient_main.sample(rad_to_deg(angle_of_attack_main))*0.5*air_density*sail_area*pow(apparent_wind.length()*inclination_angle_to_apparent_wind,2)
	# Compute drag
	aerodynamic_drag_main_force = aero_drag_coefficient_main.sample(rad_to_deg(angle_of_attack_main))*0.5*air_density*sail_area*pow(apparent_wind.length()*inclination_angle_to_apparent_wind,2)
	aerodynamic_drag_main_dir = apparent_wind.normalized()
	# Compute the total aerodynamic force
	if mainsail_inclination.y > 0:
		total_aerodynamic_force_main = (aerodynamic_lift_main_dir*aerodynamic_lift_main_force + aerodynamic_drag_main_force*aerodynamic_drag_main_dir)
	else:
		total_aerodynamic_force_main = Vector3(0.0, 0.0, 0.0)
	
	DebugDraw3D.draw_arrow(CE.global_position,CE.global_position+0.001*total_aerodynamic_force_main,Color.GREEN,0.2)
	DebugDraw3D.draw_arrow(CE.global_position,CE.global_position+0.001*aerodynamic_lift_main_dir*aerodynamic_lift_main_force,Color.BLUE,0.2)
	DebugDraw3D.draw_arrow(CE.global_position,CE.global_position+0.001*aerodynamic_drag_main_force*aerodynamic_drag_main_dir,Color.RED,0.2)
	DebugDraw3D.draw_arrow(Vector3(0,0,0),wind_direction*20,Color.YELLOW,0.5)
	
	return

## Hydrodynamic forces manager
# This function is designed to compute all the hydrodynamic forces acting on the boat
func hydrodynamic_forces_manager():
	var raw_angle := 0.0
	var raw_rudder_angle := 0.0
	var front_boat := global_transform.basis.z
	var horizontal_plane = Plane(Vector3(0.0, 1.0, 0.0))
	var vertical_inclination := global_transform.basis.y
	var water_flow : Vector3 = -horizontal_plane.project(linear_velocity)
	var water_flow_rudder : Vector3
	
	# Compute leeway angle for keel
	raw_angle = front_boat.signed_angle_to(-water_flow,Vector3(0,1,0))
	leeway_angle = PI-front_boat.angle_to(water_flow)
	
	# Compute lift for keel
	if raw_angle <= 0:
		hydrodynamic_lift_keel_dir = water_flow.cross(vertical_inclination)
	else:
		hydrodynamic_lift_keel_dir = -water_flow.cross(vertical_inclination)
	hydrodynamic_lift_keel_force = hydro_lift_coefficient_keel.sample(abs(rad_to_deg(leeway_angle)))*0.5*water_density*keel_area*pow(water_flow.length(),2)
	# Compute drag for keel
	hydrodynamic_drag_keel_dir = water_flow.normalized()
	hydrodynamic_drag_keel_force = hydro_drag_coefficient_keel.sample(abs(rad_to_deg(leeway_angle)))*0.5*water_density*keel_area*pow(water_flow.length(),2)
	
	# leeway angle for rudder
	raw_rudder_angle = raw_angle - rudder_angle
	leeway_angle_rudder = abs(raw_rudder_angle)
	water_flow_rudder = water_flow
	
	# Compute lift for rudder
	if raw_rudder_angle >= 0:
		hydrodynamic_lift_rudder_dir = water_flow_rudder.cross(vertical_inclination)
	else:
		hydrodynamic_lift_rudder_dir = -water_flow_rudder.cross(vertical_inclination)
	hydrodynamic_lift_rudder_force = hydro_lift_coefficient_rudder.sample(abs(rad_to_deg(leeway_angle_rudder)))*0.5*water_density*rudder_area*pow(water_flow_rudder.length(),2)
	# Compute drag for rudder
	hydrodynamic_drag_rudder_dir = water_flow_rudder.normalized()
	hydrodynamic_drag_rudder_force = hydro_drag_coefficient_rudder.sample(abs(rad_to_deg(leeway_angle_rudder)))*0.5*water_density*rudder_area*pow(water_flow_rudder.length(),2)
	
	# Compute total hydrodynamic force
	if vertical_inclination.y >= 0:
		total_hydrodynamic_force_keel = hydrodynamic_lift_keel_force*hydrodynamic_lift_keel_dir + hydrodynamic_drag_keel_force*hydrodynamic_drag_keel_dir
		total_hydrodynamic_force_rudder = hydrodynamic_lift_rudder_force*hydrodynamic_lift_rudder_dir + hydrodynamic_drag_rudder_force*hydrodynamic_drag_rudder_dir
	else:
		total_hydrodynamic_force_keel = Vector3(0,0,0)
		total_hydrodynamic_force_rudder = Vector3(0,0,0)
	
	# Debug
	DebugDraw3D.draw_arrow(CLR_keel.global_position,CLR_keel.global_position+0.001*hydrodynamic_lift_keel_force*hydrodynamic_lift_keel_dir,Color.BLUE,0.2)
	DebugDraw3D.draw_arrow(CLR_keel.global_position,CLR_keel.global_position+0.001*hydrodynamic_drag_keel_force*hydrodynamic_drag_keel_dir,Color.RED,0.2)
	DebugDraw3D.draw_arrow(CLR_keel.global_position,CLR_keel.global_position+0.001*total_hydrodynamic_force_keel,Color.GREEN,0.2)
	
	DebugDraw3D.draw_arrow(CLR_rudder.global_position,CLR_rudder.global_position+0.001*hydrodynamic_lift_rudder_force*hydrodynamic_lift_rudder_dir,Color.BLUE,0.2)
	DebugDraw3D.draw_arrow(CLR_rudder.global_position,CLR_rudder.global_position+0.001*hydrodynamic_drag_rudder_force*hydrodynamic_drag_rudder_dir,Color.RED,0.2)
	DebugDraw3D.draw_arrow(CLR_rudder.global_position,CLR_rudder.global_position+0.001*total_hydrodynamic_force_rudder,Color.GREEN,0.2)
	return

## Damping manager
func damping_manager():
	var yaw_damping : float
	var roll_damping : float
	var pitch_damping : float
	var boat_angular_velocity : Vector3 = get_angular_velocity()
	
	yaw_damping = -yaw_damp*boat_angular_velocity.y
	roll_damping = -roll_damp*boat_angular_velocity.z
	pitch_damping = -pitch_damp*boat_angular_velocity.x

	apply_torque(Vector3(pitch_damping,yaw_damping,roll_damping))
	return

## Reynolds Number logic
# The Reynolds number of a flow is a dimensionless quantity that predicts
# roughly how turbulent or laminar the flow is. It is important to the
# dynamics of the boat because at high Reynolds numbers both the sails and
# the keel and rudder fins become more performant. This is, drag reduces
# and lift increases by as much as 30 %.
