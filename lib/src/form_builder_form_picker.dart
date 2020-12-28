import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:permission_handler/permission_handler.dart';

class FormBuilderFilePicker extends StatefulWidget {
  final String attribute;
  final List<FormFieldValidator> validators;
  final Map<String, String> initialValue;
  final bool readonly;
  final InputDecoration decoration;
  final ValueChanged onChanged;
  final ValueTransformer valueTransformer;

  final int maxFiles;
  final bool previewImages;
  final Widget selector;
  final FileType fileType;
  final List<String> allowedExtensions;
  final Function onFileLoading;
  final bool allowCompression;
  final bool allowMultiple;
  final bool withData;

  FormBuilderFilePicker({
    @required this.attribute,
    this.initialValue,
    this.validators = const [],
    this.readonly = false,
    this.decoration = const InputDecoration(),
    this.onChanged,
    this.valueTransformer,
    this.maxFiles,
    this.previewImages = true,
    this.selector = const Text('Select File(s)'),
    this.fileType,
    this.allowedExtensions,
    this.onFileLoading,
    this.allowCompression,
    this.allowMultiple,
    this.withData,
  });

  @override
  _FormBuilderFilePickerState createState() => _FormBuilderFilePickerState();
}

class _FormBuilderFilePickerState extends State<FormBuilderFilePicker> {
  bool _readonly = false;
  final GlobalKey<FormFieldState> _fieldKey = GlobalKey<FormFieldState>();
  FormBuilderState _formState;

  // Map<String, String> _files;
  FilePickerResult _filePickerResult;

  @override
  void initState() {
    _formState = FormBuilder.of(context);
    _formState?.registerFieldKey(widget.attribute, _fieldKey);
    _readonly = (_formState?.readOnly == true) ? true : widget.readonly;
    super.initState();
  }

  @override
  void dispose() {
    _formState?.unregisterFieldKey(widget.attribute);
    super.dispose();
  }

  int get _remainingItemCount => widget.maxFiles == null
      ? null
      : widget.maxFiles - _filePickerResult.files.length;

  @override
  Widget build(BuildContext context) {
    return FormField(
      key: _fieldKey,
      enabled: !_readonly,
      initialValue: widget.initialValue,
      validator: (val) {
        for (int i = 0; i < widget.validators.length; i++) {
          if (widget.validators[i](val) != null)
            return widget.validators[i](val);
        }
        return null;
      },
      onSaved: (val) {
        if (widget.valueTransformer != null) {
          var transformed = widget.valueTransformer(val);
          FormBuilder.of(context)
              ?.setAttributeValue(widget.attribute, transformed);
        } else
          _formState?.setAttributeValue(widget.attribute, val);
      },
      builder: (FormFieldState<Map<String, String>> field) {
        return InputDecorator(
          decoration: widget.decoration.copyWith(
            enabled: !_readonly,
            errorText: field.errorText,
          ),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (widget.maxFiles != null)
                    Text(
                        "${_filePickerResult.files.length}/${widget.maxFiles}"),
                  InkWell(
                    child: widget.selector,
                    onTap: (_readonly ||
                            (_remainingItemCount != null &&
                                _remainingItemCount <= 0))
                        ? null
                        : () => pickFiles(field),
                  ),
                ],
              ),
              SizedBox(height: 3),
              defaultFileViewer(field),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickFiles(FormFieldState field) async {
    FilePickerResult resultList;

    try {
      if (await Permission.storage.request().isGranted) {
        resultList = await FilePicker.platform.pickFiles(
          type: widget.fileType,
          allowedExtensions: widget.allowedExtensions,
          allowCompression: widget.allowCompression,
          onFileLoading: widget.onFileLoading,
          allowMultiple: widget.allowMultiple,
          withData: widget.withData,
        );
      } else {
        throw new Exception("Storage Permission not granted");
      }
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    if (resultList != null) {
      field.didChange(resultList);
      widget.onChanged?.call(resultList);
    }
  }

  defaultFileViewer(FormFieldState field) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var count = 5;
        var spacing = 10;
        var itemSize = (constraints.biggest.width - (count * spacing)) / count;
        return Wrap(
          // scrollDirection: Axis.horizontal,
          alignment: WrapAlignment.start,
          runAlignment: WrapAlignment.start,
          runSpacing: 10,
          spacing: 10,
          children: _filePickerResult.files.map(
            (file) {
              return Stack(
                alignment: Alignment.topRight,
                children: <Widget>[
                  Container(
                    height: itemSize,
                    width: itemSize,
                    alignment: Alignment.center,
                    margin: EdgeInsets.only(right: 2),
                    child: (['jpg', 'jpeg', 'png'].contains(file.extension) &&
                            widget.previewImages)
                        ? Image.file(File(file.path), fit: BoxFit.cover)
                        : Container(
                            child: Icon(
                              getIconData(file.extension),
                              color: Colors.white,
                              size: 72,
                            ),
                            color: Theme.of(context).primaryColor,
                          ),
                  ),
                  if (!_readonly)
                    InkWell(
                      onTap: () => _filePickerResult.files.remove(file),
                      child: Container(
                        margin: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(.7),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        height: 22,
                        width: 22,
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          ).toList(),
        );
      },
    );
  }

  IconData getIconData(String fileExtension) {
    switch (fileExtension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
