<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * Localized language
 * * ABSPATH
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'tgoo-lojateste' );

/** Database username */
define( 'DB_USER', 'tgoo-lojateste' );

/** Database password */
define( 'DB_PASSWORD', '0q3Pm6biSUhT4ZS9vADg' );

/** Database hostname */
define( 'DB_HOST', '127.0.0.1:3306' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',          '?Wt;%.QdB4}ga#BTMUyM.UUujmkwV*$/eLfJho_QKRGW$$8CpYIO!%=e{+jGb:)g' );
define( 'SECURE_AUTH_KEY',   '0f>J{(,gQ~5Vqm&6&IiT@glv{jDDsf0Ec+VY38ZmK^3SZj=V_T%y~2k!z#B`s!fZ' );
define( 'LOGGED_IN_KEY',     '/3CbKT2JSc(0}6ZL8lep-yVL!@|U(6tZO`XcljbgQF)eaFKQ]e@r&4v(`SFKh BL' );
define( 'NONCE_KEY',         '=(4co(Mlfz4*5Sb1A=41dDCt}a-_msx/ozBkjz >6/giOjyZhktu.ADN*FG%~{t9' );
define( 'AUTH_SALT',         'Z_FBQ~XTJm:ioDUabTR?vnNOb7?{|`n5w}~IflQ.gO`ve C(b+=[Q~4(r;BNY3ox' );
define( 'SECURE_AUTH_SALT',  'b)11>LIj03<n#hiwR%:`f*[<Hr*7S`2&_#2sgw2.0%/N:Ns4$AsU2MH=43L[p&R/' );
define( 'LOGGED_IN_SALT',    'N`yK060+Z4SiK Ej]9#v>`1J3J>U,,/p[2/s0C)6*^J:%2)vc+s*]$]kk8sTC(4<' );
define( 'NONCE_SALT',        '_Y%YzHmy<73G>[:G($t+K3$Otp=!#p :K;8|RJy6~7;{OLEy<`GJmnQjy!y7hOs|' );
define( 'WP_CACHE_KEY_SALT', 's-(v}w#;z:NaT%TLI1-lR9!_F8]YmvD1)CwAJ4[vxl,3  xp^--|s~knpX@7uX18' );


/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );


/* Add any custom values between this line and the "stop editing" line. */



define( 'FS_METHOD', 'direct' );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_DEBUG_LOG', true );
define( 'CONCATENATE_SCRIPTS', false );
define( 'AUTOSAVE_INTERVAL', 600 );
define( 'WP_POST_REVISIONS', 5 );
define( 'EMPTY_TRASH_DAYS', 21 );
/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
