import 'ssh_profile.dart';

class OpenSshConfigParser {
  const OpenSshConfigParser();

  List<SshProfile> parseProfiles(
    String text, {
    String agentCommand = 'sadcoder-agent',
  }) {
    final entries = _parseEntries(text);
    final profiles = <SshProfile>[];
    final seenIds = <String>{};
    for (final entry in entries) {
      final username = entry.user?.trim();
      if (username == null || username.isEmpty) {
        continue;
      }
      for (final alias in entry.aliases) {
        if (_isWildcardHost(alias)) {
          continue;
        }
        final host =
            (entry.hostName?.trim().isNotEmpty == true ? entry.hostName : alias)
                ?.trim();
        if (host == null || host.isEmpty || _containsOpenSshToken(host)) {
          continue;
        }
        final port = entry.port ?? 22;
        final id = sshProfileId(
          host: host,
          port: port,
          username: username,
          name: alias,
        );
        if (!seenIds.add(id)) {
          continue;
        }
        profiles.add(
          SshProfile(
            id: id,
            name: alias,
            host: host,
            port: port,
            username: username,
            authType: entry.identityFile == null
                ? SshAuthType.password
                : SshAuthType.privateKey,
            agentCommand: agentCommand,
          ),
        );
      }
    }
    return List.unmodifiable(profiles);
  }

  List<_OpenSshHostEntry> _parseEntries(String text) {
    var defaults = const _OpenSshHostOptions();
    _OpenSshHostEntry? current;
    final entries = <_OpenSshHostEntry>[];
    var inMatchBlock = false;

    void flushCurrent() {
      final entry = current;
      if (entry == null) {
        return;
      }
      if (entry.isGlobalDefault) {
        defaults = defaults.merge(entry.options);
      } else if (!entry.isWildcardOnly) {
        entries.add(entry.withDefaults(defaults));
      }
      current = null;
    }

    for (final rawLine in text.split('\n')) {
      final words = _splitWords(_stripComment(rawLine.trim()));
      if (words.isEmpty) {
        continue;
      }
      final keyword = words.first.toLowerCase();
      final values = words.skip(1).toList(growable: false);
      if (keyword == 'host') {
        flushCurrent();
        inMatchBlock = false;
        current = _OpenSshHostEntry(
          aliases: values,
          options: const _OpenSshHostOptions(),
        );
        continue;
      }

      if (keyword == 'match') {
        flushCurrent();
        inMatchBlock = true;
        continue;
      }

      if (inMatchBlock) {
        continue;
      }

      final entry = current;
      if (entry == null) {
        defaults = _applyOption(defaults, keyword, values);
      } else {
        current = entry.copyWith(
          options: _applyOption(entry.options, keyword, values),
        );
      }
    }

    flushCurrent();
    return entries;
  }

  _OpenSshHostOptions _applyOption(
    _OpenSshHostOptions options,
    String keyword,
    List<String> values,
  ) {
    if (values.isEmpty) {
      return options;
    }
    final value = values.first;
    return switch (keyword) {
      'hostname' => options.copyWith(hostName: value),
      'user' => options.copyWith(user: value),
      'port' => options.copyWith(port: int.tryParse(value)),
      'identityfile' => options.copyWith(identityFile: value),
      _ => options,
    };
  }
}

String parseSshPrivateKeyPem(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final match = RegExp(
    r'-----BEGIN ([A-Z0-9 ]*PRIVATE KEY)-----[\s\S]*?-----END \1-----',
    multiLine: true,
  ).firstMatch(normalized);
  if (match == null) {
    throw const SshPrivateKeyParseException(
      SshPrivateKeyParseFailure.noPemBlock,
      'No PEM private key block found.',
    );
  }
  return match.group(0)!.trimRight();
}

enum SshPrivateKeyParseFailure { noPemBlock }

class SshPrivateKeyParseException extends FormatException {
  const SshPrivateKeyParseException(this.code, super.message);

  final SshPrivateKeyParseFailure code;
}

String _stripComment(String line) {
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (escaped) {
      buffer.write(char);
      escaped = false;
      continue;
    }
    if (char == '\\') {
      buffer.write(char);
      escaped = true;
      continue;
    }
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }
    if (char == '#' && !inSingleQuote && !inDoubleQuote) {
      break;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

List<String> _splitWords(String line) {
  final words = <String>[];
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    words.add(buffer.toString());
    buffer.clear();
  }

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (escaped) {
      buffer.write(char);
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (char.trim().isEmpty && !inSingleQuote && !inDoubleQuote) {
      flush();
      continue;
    }
    buffer.write(char);
  }
  flush();
  return words;
}

bool _isWildcardHost(String value) {
  return value.contains('*') || value.contains('?') || value.startsWith('!');
}

bool _containsOpenSshToken(String value) {
  return RegExp(r'%[a-zA-Z%]').hasMatch(value);
}

class _OpenSshHostEntry {
  const _OpenSshHostEntry({required this.aliases, required this.options});

  final List<String> aliases;
  final _OpenSshHostOptions options;

  String? get hostName => options.hostName;

  String? get user => options.user;

  int? get port => options.port;

  String? get identityFile => options.identityFile;

  bool get isWildcardOnly =>
      aliases.isNotEmpty && aliases.every(_isWildcardHost);

  bool get isGlobalDefault =>
      aliases.isNotEmpty && aliases.every((alias) => alias == '*');

  _OpenSshHostEntry copyWith({_OpenSshHostOptions? options}) {
    return _OpenSshHostEntry(
      aliases: aliases,
      options: options ?? this.options,
    );
  }

  _OpenSshHostEntry withDefaults(_OpenSshHostOptions defaults) {
    return copyWith(options: options.withDefaults(defaults));
  }
}

class _OpenSshHostOptions {
  const _OpenSshHostOptions({
    this.hostName,
    this.user,
    this.port,
    this.identityFile,
  });

  final String? hostName;
  final String? user;
  final int? port;
  final String? identityFile;

  _OpenSshHostOptions copyWith({
    String? hostName,
    String? user,
    int? port,
    String? identityFile,
  }) {
    return _OpenSshHostOptions(
      hostName: hostName ?? this.hostName,
      user: user ?? this.user,
      port: port ?? this.port,
      identityFile: identityFile ?? this.identityFile,
    );
  }

  _OpenSshHostOptions merge(_OpenSshHostOptions other) {
    return _OpenSshHostOptions(
      hostName: other.hostName ?? hostName,
      user: other.user ?? user,
      port: other.port ?? port,
      identityFile: other.identityFile ?? identityFile,
    );
  }

  _OpenSshHostOptions withDefaults(_OpenSshHostOptions defaults) {
    return _OpenSshHostOptions(
      hostName: hostName ?? defaults.hostName,
      user: user ?? defaults.user,
      port: port ?? defaults.port,
      identityFile: identityFile ?? defaults.identityFile,
    );
  }
}
