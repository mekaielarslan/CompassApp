require "singleton"
class Tray
  include Singleton

  def initialize()
    @http_server = nil
    @compass_thread = nil
    @watching_dir = nil
    @history_dirs  = App.get_history
    @shell    = App.create_shell(Swt::SWT::ON_TOP | Swt::SWT::MODELESS)
      
    @standby_icon = App.create_image("icon/16_dark.png")
    @watching_icon = App.create_image("icon/16.png")
    
    @tray_item = Swt::Widgets::TrayItem.new( App.display.system_tray, Swt::SWT::NONE)
    @tray_item.image = @standby_icon
    @tray_item.tool_tip_text = "Compass.app"
    @tray_item.addListener(Swt::SWT::Selection,  update_menu_position_handler) unless org.jruby.platform.Platform::IS_MAC
    @tray_item.addListener(Swt::SWT::MenuDetect, update_menu_position_handler)
    
    @menu = Swt::Widgets::Menu.new(@shell, Swt::SWT::POP_UP)
    
    @watch_item = add_menu_item( "Watch a Folder...", open_dir_handler)

    add_menu_separator

    @history_item = add_menu_item( "History:")
    
    @history_dirs.reverse.each do | dir |
      add_compass_item(dir)
    end

    add_menu_separator

    item =  add_menu_item( "Create Compass Project", create_project_handler, Swt::SWT::CASCADE)

    item.menu = Swt::Widgets::Menu.new( @menu )
    build_compass_framework_menuitem( item.menu, create_project_handler )
    
    item =  add_menu_item( "Preference...", preference_handler, Swt::SWT::PUSH)

    item =  add_menu_item( "About", open_about_link_handler, Swt::SWT::CASCADE)
    item.menu = Swt::Widgets::Menu.new( @menu )
    add_menu_item( 'Homepage',                      open_about_link_handler,   Swt::SWT::PUSH, item.menu)
    add_menu_item( 'Compass ' + Compass::VERSION, open_compass_link_handler, Swt::SWT::PUSH, item.menu)
    add_menu_item( 'Sass ' + Sass::VERSION,       open_sass_link_handler,    Swt::SWT::PUSH, item.menu)
    add_menu_separator( item.menu )
    
    add_menu_item( "App Version: #{App.version}",                          nil, Swt::SWT::PUSH, item.menu)
    add_menu_item( App.compile_version, nil, Swt::SWT::PUSH, item.menu)

    add_menu_item( "Quit",      exit_handler)
  end

  def run
    puts 'tray OK, spend '+(Time.now.to_f - INITAT.to_f).to_s
    while(!@shell.is_disposed) do
      App.display.sleep if(!App.display.read_and_dispatch) 
    end

    App.display.dispose

  end
  
  def rewatch
    if @watching_dir
      dir = @watching_dir
      stop_watch
      watch(dir)
    end
  end

  def add_menu_separator(menu=nil, index=nil)
    menu = @menu unless menu
    if index
    Swt::Widgets::MenuItem.new(menu, Swt::SWT::SEPARATOR, index)
    else
    Swt::Widgets::MenuItem.new(menu, Swt::SWT::SEPARATOR)
    end
  end

  def add_menu_item(label, selection_handler = nil, item_type =  Swt::SWT::PUSH, menu = nil, index = nil)
    menu = @menu unless menu
    if index
      menuitem = Swt::Widgets::MenuItem.new(menu, item_type, index)
    else
      menuitem = Swt::Widgets::MenuItem.new(menu, item_type)
    end

    menuitem.text = label
    if selection_handler
      menuitem.addListener(Swt::SWT::Selection, selection_handler ) 
    else
      menuitem.enabled = false
    end
    menuitem
  end

  def add_compass_item(dir)
    if File.exists?(dir)
      index =0
      @menu.items.each_with_index do | item, index |
	break if item.text =~ /History/
      end
      menuitem = Swt::Widgets::MenuItem.new(@menu , Swt::SWT::PUSH, index+1)
      menuitem.text = "#{dir}"
      menuitem.addListener(Swt::SWT::Selection, compass_switch_handler)
      menuitem
    end
  end

  def empty_handler
    Swt::Widgets::Listener.impl do |method, evt|
      
    end
  end

  def compass_switch_handler
    Swt::Widgets::Listener.impl do |method, evt|
      if @compass_thread
        stop_watch
      end
      watch(evt.widget.text)
    end
  end

  def open_dir_handler
    Swt::Widgets::Listener.impl do |method, evt|
      if @compass_thread
        stop_watch
      else
        dia = Swt::Widgets::DirectoryDialog.new(@shell)
        dir = dia.open
        watch(dir) if dir 
      end
    end
  end

  def build_change_options_menuitem( index )

      file_name = Compass.detect_configuration_file
      file = File.new(file_name, 'r')
      bind = binding
      eval(file.read, bind)

      @outputstyle_item = add_menu_item( "Output Style:", empty_handler , Swt::SWT::CASCADE, @menu, index)
      submenu = Swt::Widgets::Menu.new( @menu )
      @outputstyle_item.menu = submenu
      outputstyle = eval('output_style',bind) rescue 'expanded'
      
      item = add_menu_item( "nested",     outputstyle_handler, Swt::SWT::RADIO, submenu )
      item.setSelection(true) if outputstyle.to_s == "nested" 

      item = add_menu_item( "expanded",   outputstyle_handler, Swt::SWT::RADIO, submenu )
      item.setSelection(true) if outputstyle.to_s == "expanded"

      add_menu_item( "compact",    outputstyle_handler, Swt::SWT::RADIO, submenu )
      item.setSelection(true) if outputstyle.to_s == "compact"

      add_menu_item( "compressed", outputstyle_handler, Swt::SWT::RADIO, submenu )
      item.setSelection(true) if outputstyle.to_s == "compressed"

      @options_item = add_menu_item( "Options:", empty_handler , Swt::SWT::CASCADE, @menu, @menu.indexOf(@outputstyle_item)+1 )
      submenu = Swt::Widgets::Menu.new( @menu )
      @options_item.menu = submenu

      @linecomment_item  = add_menu_item( "Line Comment", linecomment_handler, Swt::SWT::CHECK, submenu )
      linecomment = eval('line_comment',bind) rescue false
      @linecomment_item.setSelection(true) if linecomment

      @debuginfo_item    = add_menu_item( "Debug Info",   debuginfo_handler,   Swt::SWT::CHECK, submenu )
      debuginfo = eval('sass_options[:debug_info]',bind) rescue false
      @debuginfo_item.setSelection(true) if debuginfo
      
  end

  def build_compass_framework_menuitem( submenu, handler )
    Compass::Frameworks::ALL.each do | framework |
      next if framework.name =~ /^_/
      item = add_menu_item( framework.name, handler, Swt::SWT::CASCADE, submenu)
      framework_submenu = Swt::Widgets::Menu.new( submenu )
      item.menu = framework_submenu
      framework.template_directories.each do | dir |
        add_menu_item( dir, handler, Swt::SWT::PUSH, framework_submenu)
      end
    end
  end

  def create_project_handler
    Swt::Widgets::Listener.impl do |method, evt|
      dia = Swt::Widgets::FileDialog.new(@shell,Swt::SWT::SAVE)
      dir = dia.open
      dir.gsub!('\\','/') if org.jruby.platform.Platform::IS_WINDOWS
      if dir
        
        # if select a pattern
        if Compass::Frameworks::ALL.any?{ | f| f.name == evt.widget.getParent.getParentItem.text }
          framework = evt.widget.getParent.getParentItem.text
          pattern = evt.widget.text
        else
          framework = evt.widget.txt
          pattern = 'project'
        end
        
        App.try do 
          actual = App.get_stdout do
            Compass::Commands::CreateProject.new( dir, {:framework => framework, :pattern => pattern } ).execute
          end
          App.report( actual)
        end

        watch(dir)
      end
    end
  end
 
  def install_project_handler
    Swt::Widgets::Listener.impl do |method, evt|
        # if select a pattern
        if Compass::Frameworks::ALL.any?{ | f| f.name == evt.widget.getParent.getParentItem.text }
          framework = evt.widget.getParent.getParentItem.text
          pattern = evt.widget.text
        else
          framework = evt.widget.txt
          pattern = 'project'
        end

        App.try do 
          actual = App.get_stdout do
            Compass::Commands::StampPattern.new( @watching_dir, {:framework => framework, :pattern => pattern } ).execute
          end
          App.report( actual)
        end

      end
  end
  
  def preference_handler 
    Swt::Widgets::Listener.impl do |method, evt|
      PreferencePanel.instance.open
    end
  end

  def open_about_link_handler 
    Swt::Widgets::Listener.impl do |method, evt|
      Swt::Program.launch('http://compass.handlino.com')
    end
  end
  
  def open_compass_link_handler
    Swt::Widgets::Listener.impl do |method, evt|
      Swt::Program.launch('http://compass-style.org/')
    end
  end
  
  def open_sass_link_handler
    Swt::Widgets::Listener.impl do |method, evt|
      Swt::Program.launch('http://sass-lang.com/')
    end
  end
  
  def exit_handler
    Swt::Widgets::Listener.impl do |method, evt|
      stop_watch
      App.set_histoy(@history_dirs[0,5])
      @shell.close
    end
  end

  def update_menu_position_handler 
    Swt::Widgets::Listener.impl do |method, evt|
      @menu.visible = true
    end
  end

  def clean_project_handler
    Swt::Widgets::Listener.impl do |method, evt|
      dir = @watching_dir
      stop_watch
      App.try do 
          actual = App.get_stdout do
            Compass::Commands::CleanProject.new(dir, {}).perform
          end
          App.report( actual)
      end
      watch(dir)
    end
  end

  def update_config(need_clean_attr, value)
      file_name = Compass.detect_configuration_file
      new_config = ''
      last_is_blank = false
      config_file = File.new(file_name,'r').each do | x | 
        next if last_is_blank && x.strip.empty?
        new_config += x unless x =~ /by Compass.app/ && x =~ Regexp.new(need_clean_attr)
        last_is_blank = x.strip.empty?
      end
      config_file.close
      new_config += "\n#{need_clean_attr} = #{value} # by Compass.app "
      File.open(file_name, 'w'){ |f| f.write(new_config) }
  end

  def outputstyle_handler
    Swt::Widgets::Listener.impl do |method, evt|
      update_config( "output_style", ":#{evt.widget.text}" )
    
      Compass::Commands::CleanProject.new(@watching_dir, {}).perform
      watch(@watching_dir)
    end
  end

  def linecomment_handler
    Swt::Widgets::Listener.impl do |method, evt|
      update_config( "line_comment", evt.widget.getSelection.to_s )
      Compass::Commands::CleanProject.new(@watching_dir, {}).perform
      watch(@watching_dir)
    end
  end
  
  def debuginfo_handler
    Swt::Widgets::Listener.impl do |method, evt|
      file_name = Compass.detect_configuration_file
      file = File.new(file_name, 'r')
      bind = binding
      eval(file.read, bind)
      file.close
      sass_options = eval('sass_option', bind) rescue {}
      sass_options = {} if !sass_options.is_a? Hash
      sass_options[:debug_info] = evt.widget.getSelection

      update_config( "sass_options", sass_options.inspect )

      Compass::Commands::CleanProject.new(@watching_dir, {}).perform
      watch(@watching_dir)
    end
  end 

  def watch(dir)
    dir.gsub!('\\','/') if org.jruby.platform.Platform::IS_WINDOWS
    App.try do 
      x = Compass::Commands::UpdateProject.new( dir, {})
      if !x.new_compiler_instance.sass_files.empty? # make sure we watch a compass project
        stop_watch

        if App::CONFIG['services'].include?( :http )
          SimpleHTTPServer.instance.start(dir, :Port =>  App::CONFIG['services_http_port'])
        end

        if App::CONFIG['services'].include?( :livereload )
          SimpleLivereload.instance.watch(dir, { :port => App::CONFIG["services_livereload_port"] }) 
        end

        current_display = App.display

        Thread.abort_on_exception = true
        @compass_thread = Thread.new do
          Compass::Commands::WatchProject.new( dir, { :logger => Compass::Logger.new({ :display => current_display,
                                                                                     :log_dir => dir}) }).execute
        end

        @watching_dir = dir
        @history_dirs.delete_if { |x| x == dir }
        @history_dirs.unshift(dir)
        @menu.items.each do |item|
          item.dispose if item.text == dir 
        end
        menuitem = add_compass_item(dir)

        @watch_item.text="Watching " + dir
        @install_item =  add_menu_item( "Install...", 
                                        install_project_handler, 
                                        Swt::SWT::CASCADE,
                                        @menu, 
                                        @menu.indexOf(@watch_item) +1 )

        @install_item.menu = Swt::Widgets::Menu.new( @menu )
        build_compass_framework_menuitem( @install_item.menu, install_project_handler )
        build_change_options_menuitem( @menu.indexOf(@install_item) +1 )
        @clean_item =  add_menu_item( "Force Recomplie", 
                                        clean_project_handler, 
                                        Swt::SWT::PUSH,
                                        @menu, 
                                        @menu.indexOf(@options_item) +1 )

        if @menu.items[ @menu.indexOf(@clean_item)+1 ].getStyle != Swt::SWT::SEPARATOR
          add_menu_separator(@menu, @menu.indexOf(@clean_item) + 1 )
        end
        @tray_item.image = @watching_icon

        
        return true

      else
        App.notify( dir +": Nothing to compile. If you're trying to start a new project, you have left off the directory argument")
      end
    end

    return false
  end

  def stop_watch
    @compass_thread.kill if @compass_thread && @compass_thread.alive?
    @compass_thread = nil
    @watch_item.text="Watch a Folder..."
    @install_item.dispose() if @install_item && !@install_item.isDisposed
    @clean_item.dispose()   if @clean_item && !@clean_item.isDisposed
    @outputstyle_item.dispose()   if @outputstyle_item && !@outputstyle_item.isDisposed
    @options_item.dispose()   if @options_item && !@options_item.isDisposed
    @watching_dir = nil
    @tray_item.image = @standby_icon
    SimpleLivereload.instance.unwatch
    SimpleHTTPServer.instance.stop
    FSEvent.stop_all_instances if Object.const_defined?("FSEvent") && FSEvent.methods.include?("stop_all_instances")
  end
  
end

