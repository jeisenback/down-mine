extends Logger
class_name ErrorLogger

## Collects the engine's script errors (a missing method, a bad assignment)
## so tests/run_tests.gd can fail the test that caused them: a runtime script
## error aborts a test body without recording a failure, so it used to pass.
var script_errors: Array[String] = []

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type == Logger.ERROR_TYPE_SCRIPT:
		script_errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])
