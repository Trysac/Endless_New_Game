extends CharacterBody2D
## Clase que controla el comportamiento de NPC
##
## Controla los dialogos con el personaje principal, escucha coliciones


# Area de contacto, para mostrar el diálogo
var _npc_dialogue_area: Node2D

@onready var _collision = $CollisionShape2D
@onready var _animation = $Npc

# Función de inicialización
func _ready():
	_npc_dialogue_area = find_child("NpcDialogueArea") # Buscamos el area de diálogo


func _physics_process(delta):
	# Agregamos la velocidad
	velocity.y += 1000 * delta
	move_and_slide() # Agregamos kinematica
	if is_on_floor():
		# Apagamos la física
		set_physics_process(false)
	

# DOCUMENTACIÓN (señales): https://docs.google.com/document/d/1bbroyXp11L4_FpHpqA-RckvFLRv3UOE-hmQdwtx27eo/edit?usp=drive_link
# Se usa para poder "escuchar" cuando el diálgo finaliza
func on_dialogue_ended(fn):
	if _npc_dialogue_area:
		_npc_dialogue_area.on_dialogue_ended(fn)


# Se usa para poder "escuchar" cuando se selecciona una respuesta en el diálogo
func on_response_selected(fn):
	if _npc_dialogue_area:
		_npc_dialogue_area.on_response_selected(fn)


# Función que deshabilita las colisiones del NPC y también la física
func set_collision_disabled(disabled: bool):
	set_physics_process(not disabled)
	_collision.disabled = disabled


# Función para rotar la animación del NPC
func flip_h(flip: bool):
	_animation.flip_h = flip


# Seteamos un nuevo diálogo y lo mostramos
func set_and_show_dialogue(resource: DialogueResource):
	if _npc_dialogue_area:
		_npc_dialogue_area.set_and_show_dialogue(resource)


# Seteamos un nuevo diálogo
func set_dialogue(resource: DialogueResource):
	if _npc_dialogue_area:
		_npc_dialogue_area.set_dialogue(resource)

