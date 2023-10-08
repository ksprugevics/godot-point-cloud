extends Control

const VIEWER_SCENE = "res://scenes//viewer.tscn"
const INT64_MAX = (1 << 63) - 1
const UNLABELED_LABEL = "__UNLABELED__"

@onready var FILE_BROWSER = $CenterContainer/VBoxContainer/PointcloudFileBrowser
@onready var TEXT_LABEL = $CenterContainer/VBoxContainer/Text
@onready var LOAD_BUTTON = $CenterContainer/VBoxContainer/VBoxContainer/LoadButton
@onready var LOADING_LABEL = $CenterContainer/VBoxContainer/VBoxContainer/LoadingLabel
@onready var FILE_BRWOSER_BUTTON = $CenterContainer/VBoxContainer/VBoxContainer/FileBrowserButton
@onready var LABEL_CHECK_BOX = $CenterContainer/VBoxContainer/VBoxContainer/LabelCheckBox
@onready var SEPERATOR_CONTAINER = $CenterContainer/VBoxContainer/VBoxContainer/SeperatorContainer
@onready var SEPERATOR_EDIT = $CenterContainer/VBoxContainer/VBoxContainer/SeperatorContainer/SeperatorTextEdit

var pointcloudPath = ""
var seperator = ""
var extent = [INT64_MAX, -INT64_MAX, INT64_MAX, -INT64_MAX, INT64_MAX, -INT64_MAX] # xmin, xmax, ymin, ymax, zmin, zmax
var useLabels = false
var labeledPoints = {}
var labelColors = {}


func _ready():
	FILE_BROWSER.visible = false
	LOAD_BUTTON.visible = false
	LOADING_LABEL.visible = false
	LABEL_CHECK_BOX.visible = false
	SEPERATOR_CONTAINER.visible = false
	get_tree().get_root().files_dropped.connect(_on_files_dropped)
	readConfig()


func readConfig():
	seperator = get_node("/root/Variables").seperator
	SEPERATOR_EDIT.text = seperator
	
	var loadLabels = get_node("/root/Variables").loadLabels
	if loadLabels != null:
		useLabels = loadLabels
	LABEL_CHECK_BOX.button_pressed = useLabels
	
	var lastPointcloudPath = get_node("/root/Variables").lastPointcloudPath
	if lastPointcloudPath != null and lastPointcloudPath != "":
		_on_pointcloud_file_browser_file_selected(lastPointcloudPath)


func _on_file_browser_button_pressed():
	FILE_BROWSER.visible = true


func _on_pointcloud_file_browser_file_selected(path):
	LOAD_BUTTON.visible = true
	LABEL_CHECK_BOX.visible = true
	SEPERATOR_CONTAINER.visible = true
	TEXT_LABEL.text = "Selected:\n" + path
	pointcloudPath = path
	get_node("/root/Variables").lastPointcloudPath = pointcloudPath


func _on_files_dropped(files):
	var selectedFile = files[0]
	if not selectedFile.get_extension() == "txt":
		push_warning("Invalid file extension")
	else:
		_on_pointcloud_file_browser_file_selected(selectedFile)


func _on_label_check_box_toggled(_button_pressed):
	useLabels = !useLabels
	get_node("/root/Variables").loadLabels = useLabels


func _on_load_button_pressed():
	FILE_BRWOSER_BUTTON.visible = false
	LOAD_BUTTON.visible = false
	LABEL_CHECK_BOX.visible = false
	SEPERATOR_CONTAINER.visible = false
	LOADING_LABEL.visible = true
	seperator = SEPERATOR_EDIT.text
	await get_tree().create_timer(0.2).timeout # without this UI doesnt get a chance to update
	processLoad()
	get_tree().change_scene_to_file(VIEWER_SCENE)


func processLoad():
	saveConfig()
	labeledPoints[UNLABELED_LABEL] = PackedVector3Array()
	loadPointcloudFile(pointcloudPath)
	translatePointcloud()
	generateRandomColors()
	updateGlobalVariables()


func saveConfig():
	get_node("/root/Variables").seperator = seperator
	get_node("/root/Variables").saveToConfig()


func loadPointcloudFile(filePath, limit=null):
	var file = FileAccess.open(filePath, FileAccess.READ)
	limit = file.get_length() if limit == null else limit

	for i in range(limit):
		var line = file.get_csv_line(seperator)
		if len(line) < 3: continue
		
		var point = Vector3(float(line[0]), float(line[2]), float(line[1]))
		updateExtents(point)
		
		var label = UNLABELED_LABEL
		if useLabels and len(line) == 4:
			label = line[3]
			if !labeledPoints.has(line[3]):
				labeledPoints[line[3]] = PackedVector3Array()
			
		labeledPoints[label].push_back(point)


func updateExtents(point):
	if point[0] <= extent[0]:
		extent[0] = point[0]
	if point[0] >= extent[1]:
		extent[1] = point[0]
	if point[1] <= extent[2]:
		extent[2] = point[1]
	if point[1] >= extent[3]:
		extent[3] = point[1]
	if point[2] <= extent[4]:
		extent[4] = point[2]
	if point[2] >= extent[5]:
		extent[5] = point[2]


func translatePointcloud():
	for label in labeledPoints.keys():
		for i in range(0, len(labeledPoints[label])):
			var normalized_x = labeledPoints[label][i][0] - extent[1]
			var normalized_z = labeledPoints[label][i][2]- extent[5]
			labeledPoints[label][i][0] = normalized_x
			labeledPoints[label][i][2] = normalized_z

	var translatedExtent = [extent[0] - extent[1], 0, extent[2], extent[3], extent[4] - extent[5], 0]
	extent = translatedExtent


func generateRandomColors():
	for label in labeledPoints.keys():
		labelColors[label] = Color(randf(), randf(), randf())


func updateGlobalVariables():
	get_node("/root/Variables").labeledPoints = labeledPoints
	get_node("/root/Variables").extent = extent
	get_node("/root/Variables").useLabels = useLabels
	get_node("/root/Variables").labelColors = labelColors
