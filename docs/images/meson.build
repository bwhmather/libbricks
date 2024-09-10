# commented-out ui files need more work

ui_files = [
  'tab-bar.ui',
]

gtk_builder_tool = find_program('gtk4-builder-tool')

if get_option('screenshots') or true
  foreach ui_file: ui_files
    png_file = ui_file.replace('.ui', '.png')
    bricks_images += custom_target(
      '@0@ from @1@'.format(png_file, ui_file),
      input: [ui_file, 'style.css'],
      output: png_file,
      command: [
        gtk_builder_tool, 'screenshot',
        '--force',
        '--css', '@INPUT1@',
        '@INPUT0@', '@OUTPUT@',
      ]
    )
  endforeach
endif
