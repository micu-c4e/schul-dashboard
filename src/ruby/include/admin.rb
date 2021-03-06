class Main < Sinatra::Base
    post '/api/impersonate' do
        require_admin!
        data = parse_request_data(:required_keys => [:email])
        session_id = create_session(data[:email], 365 * 24)
        purge_missing_sessions(session_id)
        respond(:ok => 'yeah')
    end
    
    def print_admin_dashboard()
        require_admin!
        temp = neo4j_query(<<~END_OF_QUERY).map { |x| {:session => x['s'].props, :email => x['u.email'] } }
            MATCH (s:Session)-[:BELONGS_TO]->(u:User)
            RETURN s, u.email
        END_OF_QUERY
        all_sessions = {}
        temp.each do |s|
            all_sessions[s[:email]] ||= []
            all_sessions[s[:email]] << s[:session]
        end
        all_homeschooling_users = get_all_homeschooling_users()
        StringIO.open do |io|
            io.puts "<a class='btn btn-secondary' href='#teachers'>Lehrerinnen und Lehrer</a>"
            io.puts "<a class='btn btn-secondary' href='#sus'>Schülerinnen und Schüler</a>"
            io.puts "<a class='btn btn-secondary' href='#tablets'>Tablets</a>"
            io.puts "<a class='btn btn-secondary' href='/lesson_keys'>Lesson Keys</a>"
            io.puts "<hr />"
            io.puts "<h3 id='teachers'>Lehrerinnen und Lehrer</h3>"
            io.puts "<table class='table table-condensed table-striped narrow'>"
            io.puts "<thead>"
            io.puts "<tr>"
            io.puts "<th></th>"
            io.puts "<th>Kürzel</th>"
            io.puts "<th>Name</th>"
            io.puts "<th>Vorname</th>"
            io.puts "<th>E-Mail-Adresse</th>"
            io.puts "<th>Stundenplan</th>"
            io.puts "<th>Anmelden</th>"
            io.puts "<th>Sessions</th>"
            io.puts "</tr>"
            io.puts "</thead>"
            io.puts "<tbody>"
            @@lehrer_order.each do |email|
                io.puts "<tr class='user_row'>"
                user = @@user_info[email]
                io.puts "<td>#{user_icon(email, 'avatar-md')}</td>"
                io.puts "<td>#{user[:shorthand]}</td>"
                io.puts "<td>#{user[:last_name]}</td>"
                io.puts "<td>#{user[:first_name]}</td>"
                if USE_MOCK_NAMES
                    io.puts "<td>#{user[:first_name].downcase}.#{user[:last_name].downcase}@#{SCHUL_MAIL_DOMAIN}</td>"
                else
                    io.print "<td>"
                    print_email_field(io, user[:email])
                    io.puts "</td>"
                end
                io.puts "<td><a class='btn btn-xs btn-secondary' href='/timetable/#{user[:id]}'><i class='fa fa-calendar'></i>&nbsp;&nbsp;Stundenplan</a></td>"
                io.puts "<td><button class='btn btn-warning btn-xs btn-impersonate' data-impersonate-email='#{user[:email]}'><i class='fa fa-id-badge'></i>&nbsp;&nbsp;Anmelden</button></td>"
                if all_sessions.include?(email)
                    io.puts "<td><button class='btn-sessions btn btn-xs btn-secondary' data-sessions-id='#{@@user_info[email][:id]}'>#{all_sessions[email].size} Session#{all_sessions[email].size == 1 ? '' : 's'}</button></td>"
                else
                    io.puts "<td></td>"
                end
                io.puts "</tr>"
                (all_sessions[email] || []).each do |s|
                    scrambled_sid = Digest::SHA2.hexdigest(SESSION_SCRAMBLER + s[:sid]).to_i(16).to_s(36)[0, 16]
                    io.puts "<tr class='session-row sessions-#{@@user_info[email][:id]}' style='display: none;'>"
                    io.puts "<td colspan='4'></td>"
                    io.puts "<td colspan='2'>"
                    io.puts "#{s[:user_agent] || '(unbekanntes Gerät)'}"
                    io.puts "</td>"
                    io.puts "<td>"
                    io.puts "<button class='btn btn-xs btn-danger btn-purge-session' data-email='#{email}' data-scrambled-sid='#{scrambled_sid}'>Abmelden</button>"
                    io.puts "</td>"
                    io.puts "</tr>"
                end
            end
            io.puts "</tbody>"
            io.puts "</table>"
            io.puts "<h3 id='sus'>Schülerinnen und Schüler</h3>"
            io.puts "<table class='table table-condensed table-striped narrow'>"
            io.puts "<thead>"
            io.puts "<tr>"
            io.puts "<th></th>"
            io.puts "<th>Name</th>"
            io.puts "<th>Vorname</th>"
            io.puts "<th>E-Mail-Adresse</th>"
            io.puts "<th>Stundenplan</th>"
            io.puts "<th>Anmelden</th>"
            io.puts "<th>Homeschooling</th>"
            io.puts "<th>Sessions</th>"
            io.puts "</tr>"
            io.puts "</thead>"
            io.puts "<tbody>"
            @@klassen_order.each do |klasse|
                io.puts "<tr>"
                io.puts "<th colspan='8'>Klasse #{klasse}</th>"
                io.puts "</tr>"
                (@@schueler_for_klasse[klasse] || []).each do |email|
                    io.puts "<tr class='user_row'>"
                    user = @@user_info[email]
                    io.puts "<td>#{user_icon(email, 'avatar-md')}</td>"
                    io.puts "<td>#{user[:last_name]}</td>"
                    io.puts "<td>#{user[:first_name]}</td>"
                    io.print "<td>"
                    print_email_field(io, user[:email])
                    io.puts "</td>"
                    io.puts "<td><a class='btn btn-xs btn-secondary' href='/timetable/#{user[:id]}'><i class='fa fa-calendar'></i>&nbsp;&nbsp;Stundenplan</a></td>"
                    io.puts "<td><button class='btn btn-warning btn-xs btn-impersonate' data-impersonate-email='#{user[:email]}'><i class='fa fa-id-badge'></i>&nbsp;&nbsp;Anmelden</button></td>"
                    if all_homeschooling_users.include?(email)
                        io.puts "<td><button class='btn btn-info btn-xs btn-toggle-homeschooling' data-email='#{user[:email]}'><i class='fa fa-home'></i>&nbsp;&nbsp;zu Hause</button></td>"
                    else
                        io.puts "<td><button class='btn btn-secondary btn-xs btn-toggle-homeschooling' data-email='#{user[:email]}'><i class='fa fa-building'></i>&nbsp;&nbsp;Präsenz</button></td>"
                    end
                    if all_sessions.include?(email)
                        io.puts "<td><button class='btn-sessions btn btn-xs btn-secondary' data-sessions-id='#{@@user_info[email][:id]}'>#{all_sessions[email].size} Session#{all_sessions[email].size == 1 ? '' : 's'}</button></td>"
                    else
                        io.puts "<td></td>"
                    end
                    io.puts "</tr>"
                    (all_sessions[email] || []).each do |s|
                        scrambled_sid = Digest::SHA2.hexdigest(SESSION_SCRAMBLER + s[:sid]).to_i(16).to_s(36)[0, 16]
                        io.puts "<tr class='session-row sessions-#{@@user_info[email][:id]}' style='display: none;'>"
                        io.puts "<td colspan='3'></td>"
                        io.puts "<td colspan='2'>"
                        io.puts "#{s[:user_agent] || '(unbekanntes Gerät)'}"
                        io.puts "</td>"
                        io.puts "<td>"
                        io.puts "<button class='btn btn-xs btn-danger btn-purge-session' data-email='#{email}' data-scrambled-sid='#{scrambled_sid}'>Abmelden</button>"
                        io.puts "</td>"
                        io.puts "</tr>"
                    end
                end
            end
            io.puts "</tbody>"
            io.puts "</table>"
            io.puts "<h3 id='tablets'>Tablets</h3>"
            io.puts "<hr />"
            io.puts "<p>Mit einem Klick auf diesen Button können Sie dieses Gerät dauerhaft als Lehrer-Tablet anmelden.</p>"
            io.puts "<button class='btn btn-success bu_login_teacher_tablet'><i class='fa fa-sign-in'></i>&nbsp;&nbsp;Lehrer-Tablet-Modus aktivieren</button>"
            io.puts "<hr />"
            io.puts "<p>Bitte wählen Sie ein order mehrere Kürzel, um dieses Gerät dauerhaft als Kurs-Tablet anzumelden.</p>"
            @@shorthands.keys.sort.each do |shorthand|
                io.puts "<button class='btn-teacher-for-kurs-tablet-login btn btn-xs btn-outline-secondary' data-shorthand='#{shorthand}'>#{shorthand}</button>"
            end
            io.puts "<br /><br >"
            io.puts "<button class='btn btn-success bu_login_kurs_tablet' disabled><i class='fa fa-sign-in'></i>&nbsp;&nbsp;Kurs-Tablet-Modus aktivieren</button>"
            io.puts "<hr />"
            io.puts "<p>Bitte wählen Sie ein Tablet, um dieses Gerät dauerhaft als dieses Tablet anzumelden.</p>"
            @@tablets.keys.each do |id|
                tablet = @@tablets[id]
                io.puts "<button class='btn-tablet-login btn btn-xs btn-outline-secondary' data-id='#{id}' style='background-color: #{tablet[:bg_color]}; color: #{tablet[:fg_color]};'>#{id}</button>"
            end
            io.puts "<hr />"
            io.puts "<table class='table table-condensed table-striped narrow'>"
            io.puts "<thead>"
            io.puts "<tr>"
            io.puts "<th>Typ</th>"
            io.puts "<th>Gerät</th>"
            io.puts "<th>Abmelden</th>"
            io.puts "</tr>"
            io.puts "</thead>"
            io.puts "<tbody>"
            get_sessions_for_user("lehrer.tablet@#{SCHUL_MAIL_DOMAIN}").each do |session|
                io.puts "<tr>"
                io.puts "<td>Lehrer-Tablet</td>"
                io.puts "<td>#{session[:user_agent]}</td>"
                io.puts "<td><button class='btn btn-xs btn-danger btn-purge-session' data-email='lehrer.tablet@#{SCHUL_MAIL_DOMAIN}' data-scrambled-sid='#{session[:scrambled_sid]}'>Abmelden</button></td>"
                io.puts "</tr>"
            end
            get_sessions_for_user("kurs.tablet@#{SCHUL_MAIL_DOMAIN}").each do |session|
                io.puts "<tr>"
                io.puts "<td>Kurs-Tablet (#{(session[:shorthands] || []).sort.join(', ')})</td>"
                io.puts "<td>#{session[:user_agent]}</td>"
                io.puts "<td><button class='btn btn-xs btn-danger btn-purge-session' data-email='kurs.tablet@#{SCHUL_MAIL_DOMAIN}' data-scrambled-sid='#{session[:scrambled_sid]}'>Abmelden</button></td>"
                io.puts "</tr>"
            end
            io.puts "</tbody>"
            io.puts "</table>"
            io.string
        end
    end
    
    def print_lesson_keys
        require_admin!
        StringIO.open do |io|
            io.puts "<table class='table table-condensed table-striped narrow'>"
            io.puts "<thead>"
            io.puts "<tr>"
            io.puts "<th>Lesson Key</th>"
            io.puts "<th>Fach</th>"
            io.puts "<th>Lehrer</th>"
            io.puts "<th>Klassen</th>"
            io.puts "</tr>"
            io.puts "</thead>"
            io.puts "<tbody>"
            @@lessons[:lesson_keys].keys.sort do |a, b|
                a.downcase <=> b.downcase
            end.each do |lesson_key|
                io.puts "<tr>"
                io.puts "<td>#{lesson_key}</td>"
                io.puts "<td>#{@@faecher[@@lessons[:lesson_keys][lesson_key][:fach]]}</td>"
                io.puts "<td>#{@@lessons[:lesson_keys][lesson_key][:lehrer].join(', ')}</td>"
                io.puts "<td>#{@@lessons[:lesson_keys][lesson_key][:klassen].join(', ')}</td>"
                io.puts "</tr>"
            end
            io.puts "</tbody>"
            io.puts "</table>"
            io.string
        end
    end
end
