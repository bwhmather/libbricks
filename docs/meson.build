toml_conf = configuration_data()
toml_conf.set('version', meson.project_version())

gidocgen = find_program('gi-docgen', required: get_option('documentation'), native: true)

gidocgen_common_args = [
  '--quiet',
  '--no-namespace-dir',
]

if get_option('werror')
  gidocgen_common_args += ['--fatal-warnings']
endif

docs_dir = data_dir / 'doc'

if get_option('documentation') and not generate_gir
  error('API reference requires introspection.')
endif

# XXX: gi-docgen needs a deps file
expand_content_md_files = [
  'overview.md',
]

bricks_images = []

subdir('images')

if get_option('documentation')
  bricks_toml = configure_file(
    input: 'libbricks.toml.in',
    output: 'libbricks.toml',
    configuration: toml_conf,
    install: true,
    install_dir: docs_dir / 'bricks',
  )

  custom_target('bricks-doc',
    input: [ bricks_toml, libbricks_gir[0] ],
    output: 'bricks',
    command: [
      gidocgen,
      'generate',
      gidocgen_common_args,
      '--add-include-path=@0@'.format(meson.current_build_dir() / '../../../src'),
      '--config=@INPUT0@',
      '--output-dir=@OUTPUT@',
      '--content-dir=@0@'.format(meson.current_build_dir()),
      '--content-dir=@0@'.format(meson.current_source_dir()),
      '@INPUT1@',
    ],
    depends: [ libbricks_gir[0] ] + bricks_images,
    depend_files: [ expand_content_md_files ],
    build_by_default: true,
    install: true,
    install_dir: docs_dir,
    install_tag: 'doc',
  )
endif
