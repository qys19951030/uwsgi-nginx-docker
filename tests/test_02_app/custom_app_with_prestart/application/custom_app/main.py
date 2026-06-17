import os

python_version = os.environ.get("PYTHON_VERSION", "unknown")


def application(env, start_response):
    start_response("200 OK", [("Content-Type", "text/html")])
    return [b"Hello World from Nginx uWSGI Python %b app in a Docker container" % python_version.encode("utf-8")]
