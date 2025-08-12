import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WordMemoryApp());
}

class WordMemoryApp extends StatelessWidget {
  const WordMemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '单词记忆大师',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Roboto'),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
          displayLarge: TextStyle(fontFamily: 'Roboto'),
          displayMedium: TextStyle(fontFamily: 'Roboto'),
          headlineSmall: TextStyle(fontFamily: 'Roboto'),
          titleLarge: TextStyle(fontFamily: 'Roboto'),
          titleMedium: TextStyle(fontFamily: 'Roboto'),
        ),
      ),
      home: const WordMemoryHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WordMemoryHome extends StatefulWidget {
  const WordMemoryHome({super.key});

  @override
  State<WordMemoryHome> createState() => _WordMemoryHomeState();
}

class _WordMemoryHomeState extends State<WordMemoryHome> {
  List<Word> _wordList = [];
  Set<String> _learnedWords = {};
  int _score = 0;
  int _totalAttempts = 0;
  int _correctAttempts = 0;
  
  GameMode _mode = GameMode.learn;
  bool _isPlaying = false;
  int _currentWordIndex = 0;
  Word? _currentWord;
  bool _isProcessing = false;
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _loadGameData();
  }
  
  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载单词列表
    final wordListJson = prefs.getString('word_list');
    if (wordListJson != null) {
      final List<dynamic> wordListData = jsonDecode(wordListJson);
      setState(() {
        _wordList = wordListData.map((data) => Word.fromJson(data)).toList();
      });
    }
    
    // 加载已学习单词
    final learnedWordsJson = prefs.getString('learned_words');
    if (learnedWordsJson != null) {
      final List<dynamic> learnedWordsData = jsonDecode(learnedWordsJson);
      setState(() {
        _learnedWords = learnedWordsData.cast<String>().toSet();
      });
    }
    
    // 加载游戏状态
    setState(() {
      _score = prefs.getInt('score') ?? 0;
      _totalAttempts = prefs.getInt('total_attempts') ?? 0;
      _correctAttempts = prefs.getInt('correct_attempts') ?? 0;
      _currentWordIndex = prefs.getInt('current_word_index') ?? 0;
      _isPlaying = prefs.getBool('is_playing') ?? false;
      
      // 加载游戏模式
      final modeIndex = prefs.getInt('game_mode') ?? 0;
      _mode = GameMode.values[modeIndex];
      
      // 同步导航栏索引
      switch (_mode) {
        case GameMode.learn:
          _currentIndex = 0;
          break;
        case GameMode.test:
          _currentIndex = 1;
          break;
        case GameMode.spell:
          _currentIndex = 2;
          break;
      }
    });
    
    // 如果正在游戏中，恢复当前单词
    if (_isPlaying && _currentWordIndex < _wordList.length) {
      setState(() {
        _currentWord = _wordList[_currentWordIndex];
      });
    }
  }
  
  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 保存单词列表
    final wordListData = _wordList.map((word) => word.toJson()).toList();
    await prefs.setString('word_list', jsonEncode(wordListData));
    
    // 保存已学习单词
    final learnedWordsData = _learnedWords.toList();
    await prefs.setString('learned_words', jsonEncode(learnedWordsData));
    
    // 保存游戏状态
    await prefs.setInt('score', _score);
    await prefs.setInt('total_attempts', _totalAttempts);
    await prefs.setInt('correct_attempts', _correctAttempts);
    await prefs.setInt('current_word_index', _currentWordIndex);
    await prefs.setBool('is_playing', _isPlaying);
    await prefs.setInt('game_mode', _mode.index);
  }
  
  Future<void> _resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    setState(() {
      _learnedWords.clear();
      _score = 0;
      _totalAttempts = 0;
      _correctAttempts = 0;
      _currentWordIndex = 0;
      _isPlaying = false;
      _currentWord = null;
      _mode = GameMode.learn;
      _currentIndex = 0;
    });
    
    _showFeedback('重置成功', '学习进度已重置', isError: false);
  }
  
  void _updateUI() {
    setState(() {});
  }
  
  Future<void> _importCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      
      if (result != null) {
        String content = await File(result.files.single.path!).readAsString();
        _processImportText(content);
      }
    } catch (e) {
      _showFeedback('导入失败', '无法读取文件', isError: true);
    }
  }
  
  void _processImportText(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final newWords = <Word>[];
    int invalidLines = 0;
    
    for (final line in lines) {
      final parts = line.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 2) {
        final word = parts[0];
        final meaning = parts.sublist(1).join(',').trim();
        if (word.isNotEmpty && meaning.isNotEmpty) {
          newWords.add(Word(word: word, meaning: meaning));
        } else {
          invalidLines++;
        }
      } else {
        invalidLines++;
      }
    }
    
    if (newWords.isEmpty) {
      _showFeedback('错误', '没有有效的单词数据，请检查格式', isError: true);
      return;
    }
    
    // 合并新单词，避免重复
    final existingWords = _wordList.map((w) => w.word.toLowerCase()).toSet();
    final uniqueNewWords = newWords.where((w) => !existingWords.contains(w.word.toLowerCase())).toList();
    final duplicateWords = newWords.length - uniqueNewWords.length;
    
    if (uniqueNewWords.isEmpty) {
      _showFeedback('提示', '所有 ${newWords.length} 个单词都已存在', isError: false);
      return;
    }
    
    setState(() {
      _wordList.addAll(uniqueNewWords);
    });
    
    _saveGameData();
    
    String message = '成功添加 ${uniqueNewWords.length} 个新单词';
    if (duplicateWords > 0) {
      message += '（跳过 ${duplicateWords} 个重复单词）';
    }
    if (invalidLines > 0) {
      message += '（忽略 ${invalidLines} 行无效数据）';
    }
    
    _showFeedback('成功', message, isError: false);
  }
  
  void _setMode(GameMode mode) {
    setState(() {
      _mode = mode;
      // 同步导航栏索引
      switch (mode) {
        case GameMode.learn:
          _currentIndex = 0;
          break;
        case GameMode.test:
          _currentIndex = 1;
          break;
        case GameMode.spell:
          _currentIndex = 2;
          break;
      }
    });
  }
  
  void _startGame() {
    if (_wordList.isEmpty) {
      _showFeedback('提示', '请先导入单词数据', isError: false);
      return;
    }
    
    setState(() {
      _isPlaying = true;
      _currentWordIndex = 0;
    });
    
    _nextWord();
  }
  
  void _nextWord() {
    if (_currentWordIndex >= _wordList.length - 1) {
      _endGame();
      return;
    }
    
    setState(() {
      _currentWordIndex++;
      _currentWord = _wordList[_currentWordIndex];
    });
  }
  
  void _previousWord() {
    if (_currentWordIndex <= 0) return;
    
    setState(() {
      _currentWordIndex--;
      _currentWord = _wordList[_currentWordIndex];
    });
  }
  
  void _endGame() {
    setState(() {
      _isPlaying = false;
      _currentWord = null;
    });
    
    _showFeedback('完成', '游戏结束！', isError: false);
  }
  
  Future<void> _checkTestAnswer(String selectedMeaning) async {
    if (_isProcessing || _currentWord == null) return;
    
    setState(() {
      _isProcessing = true;
      _totalAttempts++;
    });
    
    final isCorrect = selectedMeaning == _currentWord!.meaning;
    
    if (isCorrect) {
      setState(() {
        _correctAttempts++;
        _score += 10;
        _learnedWords.add(_currentWord!.word);
      });
      _showFeedback('正确！', '太棒了！', isError: false);
    } else {
      _showFeedback('错误！', '正确答案是：${_currentWord!.meaning}', isError: true);
    }
    
    await _saveGameData();
    
    setState(() {
      _currentWordIndex++;
      _isProcessing = false;
    });
    
    _nextWord();
  }
  
  Future<void> _checkSpelling(String userAnswer) async {
    if (_isProcessing || _currentWord == null) return;
    
    setState(() {
      _isProcessing = true;
      _totalAttempts++;
    });
    
    final isCorrect = userAnswer.toLowerCase() == _currentWord!.word.toLowerCase();
    
    if (isCorrect) {
      setState(() {
        _correctAttempts++;
        _score += 15;
        _learnedWords.add(_currentWord!.word);
      });
      _showFeedback('正确！', '拼写完全正确！', isError: false);
    } else {
      _showFeedback('错误！', '正确拼写是：${_currentWord!.word}', isError: true);
    }
    
    await _saveGameData();
    
    setState(() {
      _currentWordIndex++;
      _isProcessing = false;
    });
    
    _nextWord();
  }
  
  void _showHint() {
    if (_currentWord == null) return;
    
    final word = _currentWord!.word;
    final hint = '${word[0]}${'_' * (word.length - 1)}';
    _showFeedback('提示', '单词以 "${word[0]}" 开头，共 ${word.length} 个字母', isError: false);
  }
  
  void _showFeedback(String title, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  List<String> _getWrongMeanings(String correctMeaning, int count) {
    final wrongs = <String>[];
    final allMeanings = _wordList.map((w) => w.meaning).toList();
    
    final available = allMeanings.where((m) => m != correctMeaning).toList();
    
    while (wrongs.length < count && available.isNotEmpty) {
      final randomIndex = (DateTime.now().millisecondsSinceEpoch + wrongs.length) % available.length;
      wrongs.add(available[randomIndex]);
      available.removeAt(randomIndex);
    }
    
    return wrongs;
  }
  
  double get _accuracy => _totalAttempts > 0 ? (_correctAttempts / _totalAttempts) * 100 : 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单词记忆大师'),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: _wordList.isEmpty ? _buildImportScreen() : _buildGameScreen(),
      bottomNavigationBar: _wordList.isNotEmpty ? _buildBottomNavigationBar() : null,
    );
  }
  
  Widget _buildImportScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.book,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              '欢迎使用单词记忆大师',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '请导入CSV格式的单词文件开始学习',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _importCSV,
              icon: const Icon(Icons.upload_file),
              label: const Text('导入CSV文件'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CSV格式：单词,含义\n例如：apple,苹果',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameScreen() {
    return Column(
      children: [
        _buildStats(),
        _buildModeSelector(),
        Expanded(
          child: _isPlaying ? _buildGameArea() : _buildWelcomeArea(),
        ),
      ],
    );
  }
  
  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('得分', _score.toString()),
              _buildStatCard('已学会', _learnedWords.length.toString()),
              _buildStatCard('正确率', '${_accuracy.round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _resetProgress,
            icon: const Icon(Icons.refresh),
            label: const Text('重置学习进度'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildModeButton('学习', GameMode.learn),
          const SizedBox(width: 8),
          _buildModeButton('测试', GameMode.test),
          const SizedBox(width: 8),
          _buildModeButton('拼写', GameMode.spell),
        ],
      ),
    );
  }
  
  Widget _buildModeButton(String label, GameMode mode) {
    final isActive = _mode == mode;
    return ElevatedButton(
      onPressed: () => _setMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }
  
  Widget _buildWelcomeArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getModeTitle(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getModeDescription(),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _startGame,
            child: const Text('开始学习'),
          ),
        ],
      ),
    );
  }
  
  String _getModeTitle() {
    switch (_mode) {
      case GameMode.learn:
        return '学习模式';
      case GameMode.test:
        return '测试模式';
      case GameMode.spell:
        return '拼写模式';
    }
  }
  
  String _getModeDescription() {
    switch (_mode) {
      case GameMode.learn:
        return '浏览单词列表，查看单词和含义';
      case GameMode.test:
        return '选择单词的正确含义';
      case GameMode.spell:
        return '根据含义输入正确的单词拼写';
    }
  }
  
  Widget _buildGameArea() {
    if (_currentWord == null) return const SizedBox();
    
    switch (_mode) {
      case GameMode.learn:
        return _buildLearnMode();
      case GameMode.test:
        return _buildTestMode();
      case GameMode.spell:
        return _buildSpellMode();
    }
  }
  
  Widget _buildLearnMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _currentWord!.word,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentWord!.meaning,
              style: const TextStyle(
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _previousWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('上一个'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _nextWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('下一个'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_currentWordIndex + 1}/${_wordList.length}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestMode() {
    final correctMeaning = _currentWord!.meaning;
    final wrongMeanings = _getWrongMeanings(correctMeaning, 3);
    final options = [correctMeaning, ...wrongMeanings]..shuffle();
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _currentWord!.word,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '请选择正确的含义：',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((option) {
              return SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () async => await _checkTestAnswer(option),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpellMode() {
    final controller = TextEditingController();
    
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentWord!.meaning,
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '单词长度: ${_currentWord!.word.length} 字母',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 300,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '输入单词',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) async => await _checkSpelling(value),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async => await _checkSpelling(controller.text),
                  child: const Text('提交答案'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _showHint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('提示'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            switch (index) {
              case 0:
                _mode = GameMode.learn;
                _isPlaying = false;
                break;
              case 1:
                _mode = GameMode.test;
                _isPlaying = false;
                break;
              case 2:
                _mode = GameMode.spell;
                _isPlaying = false;
                break;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: '学习',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: '测试',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: '拼写',
          ),
        ],
      ),
    );
  }
}

class Word {
  final String word;
  final String meaning;
  
  Word({required this.word, required this.meaning});
  
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] as String,
      meaning: json['meaning'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
    };
  }
}

enum GameMode {
  learn,
  test,
  spell,
}