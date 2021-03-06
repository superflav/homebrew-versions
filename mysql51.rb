require 'formula'

class Mysql51 < Formula
  homepage 'http://dev.mysql.com/doc/refman/5.1/en/'
  url 'http://mysql.mirrors.pair.com/Downloads/MySQL-5.1/mysql-5.1.58.tar.gz'
  md5 'ae5aef506088e521e4b1cc4f668e96d2'

  depends_on 'readline'

  fails_with :llvm do
    build 2335
    cause "https://github.com/mxcl/homebrew/issues/issue/144"
  end

  def options
    [
      ['--with-tests', "Keep tests when installing."],
      ['--with-bench', "Keep benchmark app when installing."],
      ['--with-embedded', "Build the embedded server."],
      ['--client-only', "Only install client tools, not the server."],
      ['--universal', "Make mysql a universal binary"],
      ['--with-utf8-default', "Set the default character set to utf8"]
    ]
  end

  def patches
    DATA
  end

  def install
    # See: http://dev.mysql.com/doc/refman/5.1/en/configure-options.html
    # These flags may not apply to gcc 4+
    ENV['CXXFLAGS'] = ENV['CXXFLAGS'].gsub "-fomit-frame-pointer", ""
    ENV['CXXFLAGS'] += " -fno-omit-frame-pointer -felide-constructors"

    # Make universal for bindings to universal applications
    ENV.universal_binary if ARGV.include? '--universal'

    configure_args = [
      "--without-docs",
      "--without-debug",
      "--disable-dependency-tracking",
      "--prefix=#{prefix}",
      "--localstatedir=#{var}/mysql",
      "--sysconfdir=#{etc}",
      "--with-plugins=innobase,myisam",
      "--with-extra-charsets=complex",
      "--with-ssl",
      "--without-readline", # Confusingly, means "use detected readline instead of included readline"
      "--enable-assembler",
      "--enable-thread-safe-client",
      "--enable-local-infile",
      "--enable-shared",
      "--with-partition"]

    configure_args << "--without-server" if ARGV.include? '--client-only'
    configure_args << "--with-embedded-server" if ARGV.include? '--with-embedded'
    configure_args << "--with-charset=utf8" if ARGV.include? '--with-utf8-default'

    system "./configure", *configure_args
    system "make install"

    ln_s "#{libexec}/mysqld", bin
    ln_s "#{share}/mysql/mysql.server", bin

    (prefix+'mysql-test').rmtree unless ARGV.include? '--with-tests' # save 66MB!
    (prefix+'sql-bench').rmtree unless ARGV.include? '--with-bench'

    (prefix+'com.mysql.mysqld.plist').write startup_plist
  end

  def caveats; <<-EOS.undent
    Set up databases with:
        unset TMPDIR
        mysql_install_db

    If this is your first install, automatically load on login with:
        mkdir -p ~/Library/LaunchAgents
        cp #{prefix}/com.mysql.mysqld.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/com.mysql.mysqld.plist

    If this is an upgrade and you already have the com.mysql.mysqld.plist loaded:
        launchctl unload -w ~/Library/LaunchAgents/com.mysql.mysqld.plist
        cp #{prefix}/com.mysql.mysqld.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/com.mysql.mysqld.plist

    Note on upgrading:
        We overwrite any existing com.mysql.mysqld.plist in ~/Library/LaunchAgents
        if we are upgrading because previous versions of this brew created the
        plist with a version specific program argument.

    Or start manually with:
        mysql.server start

    This article may help in troubleshooting MySQL installs:
        http://cloudbacon.com/2011/03/20/fixing-mysql-in-homebrew/
    EOS
  end

  def startup_plist; <<-EOPLIST.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>com.mysql.mysqld</string>
      <key>Program</key>
      <string>#{bin}/mysqld_safe</string>
      <key>RunAtLoad</key>
      <true/>
      <key>UserName</key>
      <string>#{`whoami`.chomp}</string>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
    </dict>
    </plist>
    EOPLIST
  end
end


__END__
--- old/scripts/mysqld_safe.sh  2009-09-02 04:10:39.000000000 -0400
+++ new/scripts/mysqld_safe.sh  2009-09-02 04:52:55.000000000 -0400
@@ -383,7 +383,7 @@
 fi

 USER_OPTION=""
-if test -w / -o "$USER" = "root"
+if test -w /sbin -o "$USER" = "root"
 then
   if test "$user" != "root" -o $SET_USER = 1
   then
diff --git a/scripts/mysql_config.sh b/scripts/mysql_config.sh
index efc8254..8964b70 100644
--- a/scripts/mysql_config.sh
+++ b/scripts/mysql_config.sh
@@ -132,7 +132,8 @@ for remove in DDBUG_OFF DSAFEMALLOC USAFEMALLOC DSAFE_MUTEX \
               DEXTRA_DEBUG DHAVE_purify O 'O[0-9]' 'xO[0-9]' 'W[-A-Za-z]*' \
               'mtune=[-A-Za-z0-9]*' 'mcpu=[-A-Za-z0-9]*' 'march=[-A-Za-z0-9]*' \
               Xa xstrconst "xc99=none" AC99 \
-              unroll2 ip mp restrict
+              unroll2 ip mp restrict \
+              mmmx 'msse[0-9.]*' 'mfpmath=sse' w pipe 'fomit-frame-pointer' 'mmacosx-version-min=10.[0-9]'
 do
   # The first option we might strip will always have a space before it because
   # we set -I$pkgincludedir as the first option
