class Dictionary {
  Dictionary({
    required this.word,
    // required this.phonetic,
    // required this.phonetics,
    required this.meanings,
    required this.license,
    required this.sourceUrls,
  });
  // late final String phonetic;
  // late final List<Phonetics> phonetics;
  late final String word;
  late final List<Meanings> meanings;
  late final License license;
  late final List<String> sourceUrls;

  Dictionary.fromJson(Map<String, dynamic> json) {
    // phonetic = json['phonetic'];
    // phonetics =
    //     List.from(json['phonetics']).map((e) => Phonetics.fromJson(e)).toList();
    word = json['word'] ?? '';
    meanings = List.from(json['meanings'] ?? [])
        .map((e) => Meanings.fromJson(e))
        .toList();
    license = License.fromJson(json['license'] ?? {});
    sourceUrls = List.castFrom<dynamic, String>(json['sourceUrls'] ?? []);
  }

  // Map<String, dynamic> toJson() {
  //   final _data = <String, dynamic>{};
  //   _data['word'] = word;
  //   _data['phonetic'] = phonetic;
  //   _data['phonetics'] = phonetics.map((e)=>e.toJson()).toList();
  //   _data['meanings'] = meanings.map((e)=>e.toJson()).toList();
  //   _data['license'] = license.toJson();
  //   _data['sourceUrls'] = sourceUrls;
  //   return _data;
  // }
}

// class Phonetics {
//   Phonetics({
//     required this.text,
//     required this.audio,
//   });
//   late final String text;
//   late final String audio;

//   Phonetics.fromJson(Map<String, dynamic> json) {
//     text = json['text'];
//     audio = json['audio'];
//   }

//   Map<String, dynamic> toJson() {
//     final _data = <String, dynamic>{};
//     _data['text'] = text;
//     _data['audio'] = audio;
//     return _data;
//   }
// }

class Meanings {
  Meanings({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
  });
  late final String partOfSpeech;
  late final List<Definitions> definitions;
  late final List<String> synonyms;
  late final List<String> antonyms;

  Meanings.fromJson(Map<String, dynamic> json) {
    partOfSpeech = json['partOfSpeech'] ?? '';
    definitions = List.from(json['definitions'] ?? [])
        .map((e) => Definitions.fromJson(e))
        .toList();
    synonyms = List.castFrom<dynamic, String>(json['synonyms'] ?? []);
    antonyms = List.castFrom<dynamic, String>(json['antonyms'] ?? []);
  }

  // Map<String, dynamic> toJson() {
  //   final _data = <String, dynamic>{};
  //   _data['partOfSpeech'] = partOfSpeech;
  //   _data['definitions'] = definitions.map((e)=>e.toJson()).toList();
  //   _data['synonyms'] = synonyms;
  //   _data['antonyms'] = antonyms;
  //   return _data;
  // }
}

class Definitions {
  late final String definition;
  late final String example;

  Definitions({required this.definition, required this.example});

  Definitions.fromJson(Map<String, dynamic> json) {
    definition = json['definition'] ?? '';
    example = json['example'] ?? '';
  }

  // Map<String, dynamic> toJson() {
  //   final data = <String, dynamic>{};
  //   data['definition'] = definition;
  //   data['synonyms'] = synonyms;
  //   data['antonyms'] = antonyms;
  //   return data;
  // }
}

class License {
  late final String name;
  late final String url;

  License({required this.name, required this.url});

  License.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    url = json['url'] ?? '';
  }

  // Map<String, dynamic> toJson() {
  //   final _data = <String, dynamic>{};
  //   _data['name'] = name;
  //   _data['url'] = url;
  //   return _data;
  // }
}
