import 'dart:io';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/farm/farmRepo.dart';
import 'package:budget/farm/farmStrings.dart';
import 'package:budget/farm/farmTables.dart';
import 'package:budget/farm/farmUi.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/fab.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String farmStatusLabel(BuildContext context, AnimalStatus s) {
  switch (s) {
    case AnimalStatus.milking:
      return ft(context, 'status-milking');
    case AnimalStatus.dry:
      return ft(context, 'status-dry');
    case AnimalStatus.heifer:
      return ft(context, 'status-heifer');
    case AnimalStatus.calf:
      return ft(context, 'status-calf');
    case AnimalStatus.bull:
      return ft(context, 'status-bull');
    case AnimalStatus.sick:
      return ft(context, 'status-sick');
    case AnimalStatus.sold:
      return ft(context, 'status-sold');
    case AnimalStatus.dead:
      return ft(context, 'status-dead');
  }
}

Color farmStatusColor(AnimalStatus s) {
  switch (s) {
    case AnimalStatus.milking:
      return Colors.green;
    case AnimalStatus.dry:
      return Colors.orange;
    case AnimalStatus.heifer:
      return Colors.blue;
    case AnimalStatus.calf:
      return Colors.lightBlue;
    case AnimalStatus.bull:
      return Colors.brown;
    case AnimalStatus.sick:
      return Colors.red;
    case AnimalStatus.sold:
      return Colors.grey;
    case AnimalStatus.dead:
      return Colors.blueGrey;
  }
}

Future<File?> farmPhotoFile(String? fileName) async {
  if (fileName == null || fileName.isEmpty) return null;
  final dir = await getApplicationDocumentsDirectory();
  final File f = File(p.join(dir.path, 'farm_photos', fileName));
  return await f.exists() ? f : null;
}

class AnimalAvatar extends StatelessWidget {
  const AnimalAvatar({Key? key, required this.animal, this.size = 46})
      : super(key: key);
  final FarmAnimal animal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: farmStatusColor(animal.status).withOpacity(0.2),
      child: Icon(Icons.pets_rounded,
          size: size / 2, color: farmStatusColor(animal.status)),
    );
    if (animal.photoPath == null) return fallback;
    return FutureBuilder<File?>(
      future: farmPhotoFile(animal.photoPath),
      builder: (context, snapshot) {
        final File? f = snapshot.data;
        if (f == null) return fallback;
        return CircleAvatar(radius: size / 2, backgroundImage: FileImage(f));
      },
    );
  }
}

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({Key? key, this.backButton = true}) : super(key: key);
  final bool backButton;

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  AnimalStatus? filter; // null = all active
  bool showArchived = false;

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: ft(context, 'animals'),
      dragDownToDismiss: widget.backButton,
      backButton: widget.backButton,
      horizontalPaddingConstrained: true,
      floatingActionButton: AddFAB(
        tooltip: ft(context, 'add-animal'),
        onTap: () => pushRoute(context, const AnimalEditPage()),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: StreamBuilder<List<FarmAnimal>>(
            stream: FarmRepo.watchAnimals(includeArchived: showArchived),
            builder: (context, snapshot) {
              final List<FarmAnimal> all = snapshot.data ?? [];
              final List<FarmAnimal> list = all.where((a) {
                if (filter != null) return a.status == filter;
                if (showArchived) return true;
                return a.status != AnimalStatus.sold &&
                    a.status != AnimalStatus.dead;
              }).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(ft(context, 'all')),
                            selected: filter == null,
                            onSelected: (_) => setState(() => filter = null),
                          ),
                        ),
                        for (final AnimalStatus s in AnimalStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(farmStatusLabel(context, s)),
                              selected: filter == s,
                              onSelected: (_) => setState(() => filter = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 22, right: 16, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFont(
                            text: list.length.toString() +
                                ' ' +
                                ft(context, 'animal-count'),
                            fontSize: 13,
                            textColor: getColor(context, 'textLight'),
                          ),
                        ),
                        Text(ft(context, 'show-archived'),
                            style: const TextStyle(fontSize: 13)),
                        Switch(
                          value: showArchived,
                          onChanged: (v) => setState(() => showArchived = v),
                        ),
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    NoResults(message: ft(context, 'no-animals'))
                  else
                    for (final FarmAnimal a in list)
                      FarmCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        onTap: () =>
                            pushRoute(context, AnimalEditPage(animal: a)),
                        child: Row(
                          children: [
                            AnimalAvatar(animal: a),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFont(
                                    text: a.tagNumber +
                                        ((a.name ?? '').isEmpty
                                            ? ''
                                            : '  \u2022  ' + a.name!),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    maxLines: 1,
                                  ),
                                  TextFont(
                                    text: (a.breed ?? '').isEmpty
                                        ? (a.sex == AnimalSex.female
                                            ? ft(context, 'female')
                                            : ft(context, 'male'))
                                        : a.breed! +
                                            '  \u2022  ' +
                                            (a.sex == AnimalSex.female
                                                ? ft(context, 'female')
                                                : ft(context, 'male')),
                                    fontSize: 13,
                                    textColor:
                                        getColor(context, 'textLight'),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: farmStatusColor(a.status)
                                    .withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a.archived
                                    ? ft(context, 'archive')
                                    : farmStatusLabel(context, a.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: farmStatusColor(a.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 90),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnimalEditPage extends StatefulWidget {
  const AnimalEditPage({Key? key, this.animal}) : super(key: key);
  final FarmAnimal? animal;

  @override
  State<AnimalEditPage> createState() => _AnimalEditPageState();
}

class _AnimalEditPageState extends State<AnimalEditPage> {
  late final TextEditingController tagController;
  late final TextEditingController nameController;
  late final TextEditingController breedController;
  late final TextEditingController priceController;
  late final TextEditingController noteController;
  AnimalSex sex = AnimalSex.female;
  AnimalStatus status = AnimalStatus.milking;
  DateTime? dateOfBirth;
  DateTime? purchaseDate;
  String? photoPath;
  String? tagError;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final FarmAnimal? a = widget.animal;
    tagController = TextEditingController(text: a?.tagNumber ?? '');
    nameController = TextEditingController(text: a?.name ?? '');
    breedController = TextEditingController(text: a?.breed ?? '');
    priceController = TextEditingController(
        text: a?.purchasePrice == null ? '' : farmFmtNumber(a!.purchasePrice!).replaceAll(',', ''));
    noteController = TextEditingController(text: a?.note ?? '');
    if (a != null) {
      sex = a.sex;
      status = a.status;
      dateOfBirth = a.dateOfBirth;
      purchaseDate = a.purchaseDate;
      photoPath = a.photoPath;
    }
  }

  @override
  void dispose() {
    tagController.dispose();
    nameController.dispose();
    breedController.dispose();
    priceController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 900, imageQuality: 80);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final Directory photoDir = Directory(p.join(dir.path, 'farm_photos'));
      if (!await photoDir.exists()) await photoDir.create(recursive: true);
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
      await File(picked.path).copy(p.join(photoDir.path, fileName));
      if (!mounted) return;
      setState(() => photoPath = fileName);
    } catch (e) {
      print('Photo pick failed: ' + e.toString());
    }
  }

  Future<void> save() async {
    if (saving) return;
    final String tag = tagController.text.trim();
    if (tag.isEmpty) {
      setState(() => tagError = ft(context, 'required-field'));
      return;
    }
    final bool taken =
        await FarmRepo.isTagTaken(tag, exceptPk: widget.animal?.animalPk);
    if (taken) {
      if (!mounted) return;
      setState(() => tagError = ft(context, 'tag-taken'));
      return;
    }
    double? price;
    if (priceController.text.trim().isNotEmpty) {
      price = farmParseNumber(priceController.text);
      if (!farmIsValidNumber(price) || price! < 0) {
        farmMessage(ft(context, 'invalid-number'), warning: true);
        return;
      }
    }
    setState(() => saving = true);
    try {
      await FarmRepo.saveAnimal(
        animalPk: widget.animal?.animalPk,
        tagNumber: tag,
        name: nameController.text,
        breed: breedController.text,
        sex: sex,
        dateOfBirth: dateOfBirth,
        status: status,
        purchaseDate: purchaseDate,
        purchasePrice: price,
        photoPath: photoPath,
        note: noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      print('Save animal failed: ' + e.toString());
      if (!mounted) return;
      setState(() => saving = false);
      farmMessage(ft(context, 'save-failed-nothing-changed'), warning: true);
    }
  }

  Widget dateRow(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return FarmCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () async {
        final DateTime? d = await farmPickDate(context, value ?? DateTime.now());
        if (d != null) onChanged(d);
      },
      child: Row(
        children: [
          Expanded(child: TextFont(text: label, fontSize: 15)),
          TextFont(
            text: value == null ? ft(context, 'none') : farmFmtDate(context, value),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          if (value != null)
            IconButton(
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.animal != null;
    return PageFramework(
      title: isEdit ? ft(context, 'edit-animal') : ft(context, 'add-animal'),
      dragDownToDismiss: true,
      horizontalPaddingConstrained: true,
      resizeToAvoidBottomInset: true,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Center(
                child: GestureDetector(
                  onTap: pickPhoto,
                  child: photoPath == null
                      ? CircleAvatar(
                          radius: 44,
                          child: const Icon(Icons.add_a_photo_rounded, size: 30),
                        )
                      : FutureBuilder<File?>(
                          future: farmPhotoFile(photoPath),
                          builder: (context, snap) => CircleAvatar(
                            radius: 44,
                            backgroundImage:
                                snap.data == null ? null : FileImage(snap.data!),
                            child: snap.data == null
                                ? const Icon(Icons.pets_rounded)
                                : null,
                          ),
                        ),
                ),
              ),
              if (photoPath != null)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => photoPath = null),
                    child: Text(ft(context, 'remove-photo')),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
                child: TextFont(
                  text: ft(context, 'photo-backup-note'),
                  fontSize: 11.5,
                  textColor: getColor(context, 'textLight'),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'tag-number'),
                controller: tagController,
                icon: Icons.sell_outlined,
                onChanged: (_) {
                  if (tagError != null) setState(() => tagError = null);
                },
              ),
              if (tagError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 4),
                  child: Text(tagError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'animal-name'),
                controller: nameController,
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'breed'),
                controller: breedController,
                icon: Icons.pets_outlined,
              ),
              FarmFieldLabel(ft(context, 'sex')),
              FarmChoice<AnimalSex>(
                options: {
                  AnimalSex.female: ft(context, 'female'),
                  AnimalSex.male: ft(context, 'male'),
                },
                selected: sex,
                onSelected: (v) => setState(() => sex = v),
              ),
              FarmFieldLabel(ft(context, 'status')),
              FarmChoice<AnimalStatus>(
                options: {
                  for (final AnimalStatus s in AnimalStatus.values)
                    s: farmStatusLabel(context, s),
                },
                selected: status,
                onSelected: (v) => setState(() => status = v),
              ),
              const SizedBox(height: 8),
              dateRow(ft(context, 'date-of-birth'), dateOfBirth,
                  (d) => setState(() => dateOfBirth = d)),
              dateRow(ft(context, 'purchase-date'), purchaseDate,
                  (d) => setState(() => purchaseDate = d)),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'purchase-price'),
                controller: priceController,
                icon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextInput(
                labelText: ft(context, 'note'),
                controller: noteController,
                icon: Icons.notes_rounded,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (isEdit)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Button(
                            label: widget.animal!.archived
                                ? ft(context, 'unarchive')
                                : ft(context, 'archive'),
                            onTap: () async {
                              final bool ok = widget.animal!.archived ||
                                  await farmConfirm(context,
                                      ft(context, 'archive-animal-confirm'));
                              if (!ok) return;
                              await FarmRepo.setAnimalArchived(
                                  widget.animal!.animalPk,
                                  !widget.animal!.archived);
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: Button(
                        label: ft(context, 'save'),
                        onTap: save,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }
}
