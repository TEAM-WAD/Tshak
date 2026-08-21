[app]

# (str) Title of your application
title = Follower X

# (str) Package name
package.name = followerx

# (str) Package domain (needed for android/ios packaging)
package.domain = com.followerx.app

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (let empty to include all the files)
source.include_exts = py,png,jpg,kv,atlas,db

# (list) List of inclusions using pattern matching
#source.include_patterns = assets/*,images/*.png

# (list) Source files to exclude (let empty to not exclude anything)
#source.exclude_exts = spec

# (list) List of directory to exclude (let empty to not exclude anything)
#source.exclude_dirs = tests, bin, venv

# (list) List of exclusions using pattern matching
#source.exclude_patterns = license,README.md

# (str) Application versioning (method 1)
version = 1.0.0

# (list) Application requirements
# comma separated e.g. requirements = sqlite3,kivy
requirements = python3,flet,requests,urllib3,certifi,idna,charset-normalizer,sqlite3

# (str) Custom source folders for requirements
# Sets custom source for any requirement with recipes
# requirements.source.kivy = ../kivy

# (str) Presplash of the application
#presplash.filename = %(source.dir)s/cached_logo.png

# (str) Icon of the application
#icon.filename = %(source.dir)s/cached_logo.png

# (str) Supported orientation (one of landscape, sensorLandscape, portrait or all)
orientation = portrait

# (list) List of service to declare
#services = Name:service.py:foreground

#
# Android specific
#

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 0

# (string) Presplash background color (for android toolchain)
# Supported formats are: #RRGGBB #AARRGGBB or one of the valid color names:
# red, blue, green, etc.
android.presplash_color = #06060B

# (list) Permissions
android.permissions = INTERNET, ACCESS_NETWORK_STATE, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE

# (int) Target Android API, should be as high as possible.
android.api = 33

# (int) Minimum API required
android.minapi = 21

# (int) Android SDK version to use
android.sdk = 33

# (str) Android NDK version to use
android.ndk = 25b

# (bool) Use --private data dir (True) or --dir public storage (False)
#android.private_storage = True

# (str) Android NDK directory (if empty, it will be automatically downloaded.)
#android.ndk_path =

# (str) Android SDK directory (if empty, it will be automatically downloaded.)
#android.sdk_path =

# (str) ANT directory (if empty, it will be automatically downloaded.)
#android.ant_path =

# (bool) If True, then skip trying to update the Android sdk
# This should be True, if the android SDK is already installed.
android.skip_update = False

# (bool) If True, then automatically accept SDK licenses
# this is needed for automated builds e.g. where you do not have a terminal prompt
android.accept_sdk_license = True

# (str) Android entry point, default is ok for Kivy-based app
#android.entrypoint = org.kivy.android.PythonActivity

# (list) List of Java .jar files to add to the libs so that pyjnius can access
# their classes. Don't add jars that you do not need, since extra jars can slow
# down the build process. Allows wildcards matching, for example:
# android.add_jars = foo.jar,bar.jar,path/to/a/jar/*.jar
#android.add_jars = foo.jar

# (list) List of Java files to add to the android project (for example, vignettes)
#android.add_src =

# (list) Android AAR archives to add
#android.add_aars =

# (list) Gradle dependencies to add
#android.gradle_dependencies =

# (bool) Enable AndroidX support. Required when targeting Android 9.0+ (API 28+)
android.enable_androidx = True

# (list) Packaging options to pass to Android build
#android.add_packaging_options =

# (list) Java classes to add as activities to the manifest
#android.add_activities = com.example.ExampleActivity

# (str) OUIA support
#android.ouya.category = GAME

# (str) OUIA icon filename
#android.ouya.icon.filename = %(source.dir)s/data/ouya_icon.png

# (list) Supported architectures
android.archs = arm64-v8a, armeabi-v7a

# (bool) enable Python app grant storage permissions
android.allow_backup = True

#
# Python for android (p4a) specific
#

# (str) python-for-android git clone directory (if empty, it will be automatically downloaded.)
#p4a.source_dir =

# (str) The directory in which python-for-android should look for your own build recipes (if any)
#p4a.local_recipes =

# (str) Filename to the hook for p4a
#p4a.hook =

# (str) Bootstrap to use for android build
#p4a.bootstrap = sdl2

# (int) port number to specify an explicit --port=FLAG when running --serve
#p4a.port = 9001

[buildozer]

# (int) Log level (0 = error only, 1 = info, 2 = debug (with command output))
log_level = 2

# (int) Display warning if buildozer is run as root (0 = ignore, 1 = warn, 2 = error)
warn_on_root = 1
