import '../../parsers/agro_bank_parser.dart';
import '../../parsers/deeqtoon_parser.dart';
import '../../parsers/evc_plus_parser.dart';
import '../../parsers/generic_financial_parser.dart';
import '../../parsers/jeeb_parser.dart';
import 'financial_sms_parser_registry.dart';
import 'financial_sms_pipeline.dart';

FinancialSmsPipeline createFinancialSmsPipeline() => FinancialSmsPipeline(
  FinancialSmsParserRegistry([
    EvcPlusParser(),
    JeebParser(),
    DeeqtoonParser(),
    AgroBankParser(),
    GenericFinancialParser(),
  ]),
);
