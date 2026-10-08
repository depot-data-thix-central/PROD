const _kGold = Color(0xFFFFB800);
const _kDark = Color(0xFF101840);
const _kBorder = Color(0xFFECEEF4);

class AdminArticleFormPage extends StatefulWidget {
  final String? articleId;
  const AdminArticleFormPage({super.key, this.articleId});
  @override State<AdminArticleFormPage> createState() => _AdminArticleFormPageState();
}

class _AdminArticleFormPageState extends State<AdminArticleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _content = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  
  String _category = 'politique';
  bool _isFeatured = false, _isBreaking = false;
  String? _imageUrl; String? _videoUrl;
  XFile? _pickedImage; XFile? _pickedVideo;
  Uint8List? _imgBytes; Uint8List? _vidBytes;
  bool _loading = false;
  NewsArticle? _edit;
  final cats = ['politique','economie','societe','tech','sport','culture','international'];

  @override void initState(){super.initState(); if(widget.articleId!=null)_load();}
  
  Future<void> _load() async {}
  Future<void> _pickImage() async {}
  Future<void> _pickVideo() async {}
  Future<void> _save() async {}

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title:Text(_edit==null?'Nouvel Article':'Modifier',style:const TextStyle(fontWeight:FontWeight.w800)),backgroundColor:_kDark,foregroundColor:Colors.white),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Composants du formulaire
          ],
        ),
      ),
    );
  }
}
