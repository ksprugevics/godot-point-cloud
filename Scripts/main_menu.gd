extends Control

const VIEWER_SCENE = "res://scenes//viewer.tscn"
const INT64_MAX = (1 << 63) - 1

@onready var FILE_BROWSER = $CenterContainer/VBoxContainer/PointcloudFileBrowser
@onready var TEXT_LABEL = $CenterContainer/VBoxContainer/Text
@onready var LOAD_BUTTON = $CenterContainer/VBoxContainer/VBoxContainer/LoadButton
@onready var LOADING_LABEL = $CenterContainer/VBoxContainer/VBoxContainer/LoadingLabel
@onready var FILE_BRWOSER_BUTTON = $CenterContainer/VBoxContainer/VBoxContainer/FileBrowserButton

var pointcloudPath = ""
var points = PackedVector3Array()
var pointLabelMask = []
var pointLabels = []
var extent = [INT64_MAX, -INT64_MAX, INT64_MAX, -INT64_MAX, INT64_MAX, -INT64_MAX] # xmin, xmax, zmin zmax, ymin, ymax


func _ready():
	FILE_BROWSER.visible = false
	LOAD_BUTTON.visible = false
	LOADING_LABEL.visible = false
	get_tree().get_root().files_dropped.connect(_on_files_dropped)


func _on_file_browser_button_pressed():
	FILE_BROWSER.visible = true


func _on_pointcloud_file_browser_file_selected(path):
	LOAD_BUTTON.visible = true
	TEXT_LABEL.text = "Selected:\n" + path
	pointcloudPath = path


func _on_files_dropped(files):
	var selectedFile = files[0]
	if not selectedFile.get_extension() == "txt":
		push_warning("Invalid file extension")
	else:
		_on_pointcloud_file_browser_file_selected(selectedFile)


func _on_load_button_pressed():
	FILE_BRWOSER_BUTTON.visible = false
	LOAD_BUTTON.visible = false
	LOADING_LABEL.visible = true
	await get_tree().create_timer(0.2).timeout # without this UI doesnt get a chance to update
	loadPointcloudFile(pointcloudPath)
	LOADING_LABEL.visible = false
	get_node("/root/Variables").points = points
	get_node("/root/Variables").pointLabelMask = pointLabelMask
	get_node("/root/Variables").pointLabels = pointLabels
	get_node("/root/Variables").extent = extent
	
	# Create a promt to load anyway
	if len(points) != len(pointLabelMask):
		push_warning("Point array length and mask length is not the same. Invalid labels")
	
	get_tree().change_scene_to_file(VIEWER_SCENE)


func loadPointcloudFile(filePath, limit=null, labels=true):
	var file = FileAccess.open(filePath, FileAccess.READ)
	limit = file.get_length() if limit == null else limit

	for i in range(limit):
		var coordinate = file.get_csv_line(" ")
		if len(coordinate) != 4 and labels: continue
		var x = float(coordinate[0])
		var z = float(coordinate[1])
		var y = float(coordinate[2])
		
		points.push_back(Vector3(x, y, z))
		
		pointLabelMask.append(coordinate[3])
		
		if !pointLabels.has(coordinate[3]):
			pointLabels.append(coordinate[3])

		if x <= extent[0]:
			extent[0] = x
		if x >= extent[1]:
			extent[1] = x
		if y <= extent[2]:
			extent[2] = y
		if y >= extent[3]:
			extent[3] = y
		if z <= extent[4]:
			extent[4] = z
		if z >= extent[5]:
			extent[5] = z
