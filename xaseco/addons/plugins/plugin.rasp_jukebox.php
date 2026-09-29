<?php
/**
 * pyseco jukebox bridge - stands in for RASP's plugin.rasp_jukebox.php.
 *
 * The jukebox lives in pyseco (plugins/jukebox.py): it decides which map comes next. This file keeps
 * XAseco and its plugins working that expect RASP's jukebox:
 *  - $jukebox and $jb_buffer mirror pyseco's queue and history (Records-Eyepiece shows them)
 *  - chat_jukebox() takes wishes from Records-Eyepiece's track list and forwards them to pyseco
 *  - changes other plugins make to $jukebox directly (chat.admin: /admin replay, dropjukebox,
 *    clearjukebox, add) are forwarded to pyseco
 *  - functions other plugins call directly exist, so XAseco never stops on a missing function
 *
 * Protocol: the server swaps the Echo parameters and XAseco's onEcho only gets the first one, so
 * both sides send Echo('<channel>|<json>', '<channel>'): 'pyseco-shim' from here, 'pyseco' from pyseco.
 */

require_once('includes/rasp.funcs.php');  // functions for the RASP plugins

Aseco::registerEvent('onSync', 'pyjb_sync');
Aseco::registerEvent('onEcho', 'pyjb_echo');
Aseco::registerEvent('onEverySecond', 'pyjb_check');

global $jukebox, $jb_buffer, $pyjb_known, $tmxadd, $tmxplaying, $tmxplayed, $chatvote, $plrvotes;
$jukebox = array();     // uid => entry, in pyseco's order
$jb_buffer = array();   // uids of recently played maps, oldest first
$pyjb_known = array();  // uids of $jukebox as pyseco sent them
$tmxadd = array();
$tmxplaying = false;
$tmxplayed = false;
$chatvote = array();
$plrvotes = array();

function pyjb_send($aseco, $request) {
	$aseco->client->query('Echo', 'pyseco-shim|' . json_encode($request), 'pyseco-shim');
}

// XAseco (re)started: ask pyseco for the current state
function pyjb_sync($aseco, $data) {
	pyjb_send($aseco, array('action' => 'hello'));
}

// $params: the callback's parameters (Internal, Public); Public is the first parameter of the Echo call
function pyjb_echo($aseco, $params) {
	global $jukebox, $jb_buffer, $pyjb_known;

	$public = is_array($params) && isset($params[1]) ? $params[1] : '';
	if (!is_string($public) || strpos($public, 'pyseco|') !== 0) return;
	$state = json_decode(substr($public, strlen('pyseco|')), true);
	if (!is_array($state)) return;

	$was_empty = empty($jukebox);
	$before = array_keys($jukebox);
	$jukebox = array();
	foreach ($state['queue'] as $entry)
		$jukebox[$entry['uid']] = $entry;
	$jb_buffer = $state['history'];
	$pyjb_known = array_keys($jukebox);
	if ($pyjb_known != $before)
		$aseco->console('[pyseco jukebox] {1} map(s) in the jukebox', count($jukebox));

	// let Records-Eyepiece refresh its "next track"
	if (empty($jukebox)) {
		if (!$was_empty)
			$aseco->releaseEvent('onJukeboxChanged', array('clear', null));
	} else {
		$aseco->releaseEvent('onJukeboxChanged', array('add', reset($jukebox)));
	}
}

// forwards what other plugins changed in $jukebox directly (they check their admin rights themselves)
function pyjb_check($aseco, $data) {
	global $jukebox, $pyjb_known;

	$current = array_keys($jukebox);
	foreach (array_diff($current, $pyjb_known) as $uid) {
		$entry = $jukebox[$uid];
		pyjb_send($aseco, array('action' => 'add', 'uid' => $uid, 'filename' => $entry['FileName'],
		                        'name' => $entry['Name'], 'env' => isset($entry['Env']) ? $entry['Env'] : '',
		                        'login' => $entry['Login'], 'nickname' => $entry['Nick'],
		                        'source' => $entry['source'], 'tmx' => !empty($entry['tmx']), 'admin' => true));
	}
	foreach (array_diff($pyjb_known, $current) as $uid)
		pyjb_send($aseco, array('action' => 'drop', 'uid' => $uid, 'login' => '', 'admin' => true));
	$pyjb_known = $current;  // pyseco answers with the real state
}

// Records-Eyepiece's track list: puts the chosen map into $player->tracklist and calls this with 1,
// or 'drop' to remove the player's own map
function chat_jukebox($aseco, $command) {
	$player = $command['author'];
	$param = $command['params'];
	if (is_numeric($param) && $param >= 1) {
		if (empty($player->tracklist) || !isset($player->tracklist[$param - 1])) return;
		$track = $player->tracklist[$param - 1];
		pyjb_send($aseco, array('action' => 'add', 'uid' => $track['uid'], 'filename' => $track['filename'],
		                        'name' => $track['name'], 'env' => $track['environment'],
		                        'login' => $player->login, 'nickname' => $player->nickname,
		                        'source' => 'Jukebox', 'tmx' => false, 'admin' => $aseco->isAnyAdmin($player)));
	} elseif ($param == 'drop') {
		global $jukebox;
		foreach ($jukebox as $uid => $entry) {
			if ($entry['Login'] == $player->login) {
				pyjb_send($aseco, array('action' => 'drop', 'uid' => $uid, 'login' => $player->login,
				                        'admin' => false));
				break;
			}
		}
	}
}

// called by other XAseco code, handled by pyseco's commands (/list, /jukebox) or not supported (TMX votes)
function chat_list($aseco, $command) {
	$aseco->client->query('ChatSendServerMessageToLogin',
	                      $aseco->formatColors('{#server}> Use {#highlite}/list{#server} or {#highlite}/elist'),
	                      $command['author']->login);
}
function chat_y($aseco, $command) {}
function rasp_newtrack($aseco, $data) {}
function init_jbhistory($aseco, $data) {}
?>
