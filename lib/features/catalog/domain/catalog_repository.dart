import '../../../core/result/app_result.dart';
import 'portfolio_item.dart';
import 'service_item.dart';
import 'team_member.dart';

abstract class CatalogRepository {
  Future<AppResult<List<ServiceItem>>> getServices({bool activeOnly = true});
  Future<AppResult<ServiceItem>> getServiceBySlug(String slug);
  Future<AppResult<ServiceItem>> getServiceById(String id);
  Future<AppResult<ServiceItem>> createService(ServiceItem item);
  Future<AppResult<ServiceItem>> updateService(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deleteService(String id);

  Future<AppResult<List<PortfolioItem>>> getPortfolioItems({
    bool activeOnly = true,
    bool featuredOnly = false,
  });
  Future<AppResult<PortfolioItem>> getPortfolioBySlug(String slug);
  Future<AppResult<PortfolioItem>> getPortfolioById(String id);
  Future<AppResult<PortfolioItem>> createPortfolioItem(PortfolioItem item);
  Future<AppResult<PortfolioItem>> updatePortfolioItem(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deletePortfolioItem(String id);

  Future<AppResult<List<TeamMember>>> getTeamMembers({bool activeOnly = true});
  Future<AppResult<TeamMember>> getTeamMemberById(String id);
  Future<AppResult<TeamMember>> createTeamMember(TeamMember member);
  Future<AppResult<TeamMember>> updateTeamMember(String id, Map<String, dynamic> data);
  Future<AppResult<void>> deleteTeamMember(String id);
}
