project(
  'libbricks', 'vala',
  version: '1.0.alpha',
  license: 'LGPL-2.1-or-later',
  meson_version: '>= 1.3.0',
)

gnome = import('gnome')
pkgconfig = import('pkgconfig')

cc = meson.get_compiler('c')

version_arr = meson.project_version().split('-')[0].split('.')
version_major = version_arr[0].to_int()
version_minor = version_arr[1].to_int()
if version_arr[2].startswith('alpha') or version_arr[2].startswith('beta') or version_arr[2].startswith('rc')
  version_micro = 0
else
  version_micro = version_arr[2].to_int()
endif

package_subdir = get_option('package_subdir') # When used as subproject
if package_subdir != ''
  include_dir = get_option('includedir') / package_subdir / f'libbricks-@version_major@'
  data_dir = get_option('datadir') / package_subdir
  lib_dir = get_option('libdir') / package_subdir
  gir_dir = get_option('datadir') / package_subdir / 'gir-1.0'
  typelib_dir = get_option('libdir') / package_subdir / 'girepository-1.0'
  vapi_dir = get_option('datadir') / package_subdir / 'vapi'
else
  include_dir = get_option('includedir') / f'libbricks-@version_major@'
  data_dir = get_option('datadir')
  lib_dir = get_option('libdir')
  gir_dir = get_option('datadir') / 'gir-1.0'
  typelib_dir = get_option('libdir') / 'girepository-1.0'
  vapi_dir = get_option('datadir') / 'vapi'
endif

config_data = configuration_data()
config_data.set_quoted('G_LOG_DOMAIN', 'Bricks')
config_data.set_quoted('GETTEXT_PACKAGE', 'libbricks')
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('BRK_DATA_PREFIX', get_option('prefix'))
config_data.set('BRK_VERSION_MAJOR', version_major)
config_data.set('BRK_VERSION_MINOR', version_minor)
config_data.set('BRK_VERSION_MICRO', version_micro)
config_h = configure_file(output: 'libbricks-config.h', configuration: config_data)

add_project_arguments(
  '--vapidir', meson.current_source_dir() / 'vapi',
  '--enable-deprecated',
  '--abi-stability',
  language: 'vala'
)

add_project_arguments([
  '-include', config_h.full_path(),
  '-Wno-pedantic',
  '-Wno-discarded-qualifiers',
  '-Wno-unused-but-set-variable',
  '-Wno-unused-function',
  '-Wno-unused-parameter',
  '-Wno-unused-variable',
], language: 'c')

glib_dep = dependency('glib-2.0')
gio_dep = dependency('gio-2.0')
gtk_dep = dependency('gtk4', include_type: 'system')
math_dep = cc.find_library('m')

deps = [
  math_dep,
  glib_dep,
  gio_dep,
  gtk_dep,
]

public_deps = [
  glib_dep,
  gio_dep,
  gtk_dep,
]

sources = [
  'src/brk-main.vala',
  'src/brk-button-group.vala',
  'src/brk-preferences.vala',
  'src/brk-statusbar.vala',
  'src/brk-style-manager.vala',
  'src/brk-tab-view.vala',
  'src/brk-toolbar.vala',
  'src/brk-toolbar-view.vala',
]

sources += gnome.compile_resources(
    'brk-resources',
    'src/resources/bricks.gresources.xml',
    source_dir: 'src/resources',
)

libbricks = shared_library(
  f'bricks-@version_major@',
  sources,
  vala_header: 'bricks.h',
  vala_vapi: f'libbricks-@version_major@.vapi',
  vala_gir: f'Brk-@version_major@.@version_minor@.gir',
  vala_args: [
    '--pkg', 'config',
  ],
  soversion: version_minor,
  dependencies: deps,
  install: true,
  install_dir: [lib_dir, include_dir, true, true]
)

libbricks_dep = declare_dependency(
  dependencies: public_deps,
  link_with: libbricks,
  include_directories: include_directories('.'),
)

if not meson.is_subproject()
    subdir('docs')
endif
